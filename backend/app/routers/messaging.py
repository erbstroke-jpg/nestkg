from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy import or_, and_, func
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.models.user import User, UserStatus
from app.models.listing import Listing
from app.models.conversation import Conversation
from app.models.message import Message, MessageType
from app.models.message_attachment import MessageAttachment
from app.models.notification import Notification, NotificationType
from app.schemas.messaging import (
    ConversationOut, ConversationParticipant, MessageOut,
    CreateConversationRequest, SendMessageRequest,
)
from app.dependencies.auth import get_current_user
from app.dependencies.pagination import get_pagination, PaginationParams, paginated_response
from app.utils.files import save_upload_file
from app.config import settings

router = APIRouter(tags=["Messaging"])


# ── helpers ──────────────────────────────────────────

def _user_in_conversation(user_id: int, conv: Conversation) -> bool:
    return user_id in (conv.participant_a_id, conv.participant_b_id)


def _get_other_participant(user_id: int, conv: Conversation) -> User:
    return conv.participant_b if conv.participant_a_id == user_id else conv.participant_a


def _normalize_participants(user_a: int, user_b: int) -> tuple[int, int]:
    """Always store smaller id as participant_a to avoid duplicates."""
    return (min(user_a, user_b), max(user_a, user_b))


def _conv_to_out(conv: Conversation, current_user_id: int, db: Session) -> ConversationOut:
    # Last message preview
    last_msg = (
        db.query(Message)
        .filter(Message.conversation_id == conv.id, Message.deleted_at == None)
        .order_by(Message.sent_at.desc())
        .first()
    )
    preview = None
    if last_msg:
        if last_msg.text_body:
            preview = last_msg.text_body[:80]
        elif last_msg.message_type == MessageType.attachment:
            preview = "[Attachment]"

    # Unread count
    unread = (
        db.query(func.count(Message.id))
        .filter(
            Message.conversation_id == conv.id,
            Message.sender_id != current_user_id,
            Message.is_read == False,
            Message.deleted_at == None,
        )
        .scalar()
    )

    return ConversationOut(
        id=conv.id,
        listing_id=conv.listing_id,
        participant_a=ConversationParticipant.model_validate(conv.participant_a),
        participant_b=ConversationParticipant.model_validate(conv.participant_b),
        last_message_at=conv.last_message_at,
        last_message_preview=preview,
        unread_count=unread or 0,
        created_at=conv.created_at,
    )


# ── conversations ────────────────────────────────────

@router.post("/conversations", response_model=ConversationOut, status_code=status.HTTP_201_CREATED)
def create_conversation(
    req: CreateConversationRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if req.recipient_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot message yourself")

    # Validate recipient
    recipient = db.query(User).filter(User.id == req.recipient_id).first()
    if not recipient or recipient.status in (UserStatus.deleted, UserStatus.blocked):
        raise HTTPException(status_code=404, detail="Recipient not found or unavailable")

    # Validate listing
    listing = db.query(Listing).filter(Listing.id == req.listing_id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")

    # Check if conversation already exists
    a_id, b_id = _normalize_participants(current_user.id, req.recipient_id)
    existing = db.query(Conversation).filter(
        Conversation.participant_a_id == a_id,
        Conversation.participant_b_id == b_id,
        Conversation.listing_id == req.listing_id,
    ).first()

    if existing:
        # Send initial message to existing conversation if provided
        if req.initial_message:
            _send_message(db, existing, current_user.id, req.initial_message)
        return _conv_to_out(existing, current_user.id, db)

    # Create new conversation
    conv = Conversation(
        listing_id=req.listing_id,
        participant_a_id=a_id,
        participant_b_id=b_id,
    )
    db.add(conv)
    db.commit()
    db.refresh(conv)

    # Reload with relationships
    conv = db.query(Conversation).options(
        joinedload(Conversation.participant_a),
        joinedload(Conversation.participant_b),
    ).filter(Conversation.id == conv.id).first()

    if req.initial_message:
        _send_message(db, conv, current_user.id, req.initial_message)

    return _conv_to_out(conv, current_user.id, db)


@router.get("/conversations")
def list_conversations(
    pagination: PaginationParams = Depends(get_pagination),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = (
        db.query(Conversation)
        .options(
            joinedload(Conversation.participant_a),
            joinedload(Conversation.participant_b),
        )
        .filter(
            or_(
                Conversation.participant_a_id == current_user.id,
                Conversation.participant_b_id == current_user.id,
            )
        )
        .order_by(
    func.coalesce(Conversation.last_message_at, Conversation.created_at).desc(), Conversation.created_at.desc())
    )

    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()
    result = [_conv_to_out(c, current_user.id, db) for c in items]

    return paginated_response(result, total, pagination)


@router.get("/conversations/{conversation_id}", response_model=ConversationOut)
def get_conversation(
    conversation_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    conv = (
        db.query(Conversation)
        .options(
            joinedload(Conversation.participant_a),
            joinedload(Conversation.participant_b),
        )
        .filter(Conversation.id == conversation_id)
        .first()
    )
    if not conv or not _user_in_conversation(current_user.id, conv):
        raise HTTPException(status_code=404, detail="Conversation not found")

    return _conv_to_out(conv, current_user.id, db)


# ── messages ─────────────────────────────────────────

def _send_message(db: Session, conv: Conversation, sender_id: int, text: str) -> Message:
    msg = Message(
        conversation_id=conv.id,
        sender_id=sender_id,
        text_body=text,
        message_type=MessageType.text,
    )
    db.add(msg)
    conv.last_message_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(msg)

    # Create notification for the other participant
    recipient_id = conv.participant_b_id if conv.participant_a_id == sender_id else conv.participant_a_id
    notif = Notification(
        user_id=recipient_id,
        type=NotificationType.new_message,
        title="New message",
        body=text[:100],
        reference_type="conversation",
        reference_id=conv.id,
    )
    db.add(notif)
    db.commit()

    return msg


@router.post("/conversations/{conversation_id}/messages", response_model=MessageOut, status_code=201)
def send_message(
    conversation_id: int,
    req: SendMessageRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    conv = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if not conv or not _user_in_conversation(current_user.id, conv):
        raise HTTPException(status_code=404, detail="Conversation not found")

    if not req.text_body:
        raise HTTPException(status_code=400, detail="Message text is required")

    msg = _send_message(db, conv, current_user.id, req.text_body)
    return MessageOut.model_validate(msg)


@router.get("/conversations/{conversation_id}/messages")
def get_messages(
    conversation_id: int,
    pagination: PaginationParams = Depends(get_pagination),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    conv = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if not conv or not _user_in_conversation(current_user.id, conv):
        raise HTTPException(status_code=404, detail="Conversation not found")

    query = (
        db.query(Message)
        .options(joinedload(Message.attachments))
        .filter(Message.conversation_id == conversation_id, Message.deleted_at == None)
        .order_by(Message.sent_at.desc())
    )

    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()

    # Mark messages as read
    db.query(Message).filter(
        Message.conversation_id == conversation_id,
        Message.sender_id != current_user.id,
        Message.is_read == False,
    ).update({"is_read": True})
    db.commit()

    return paginated_response(
        [MessageOut.model_validate(m) for m in items],
        total,
        pagination,
    )


# ── attachments ──────────────────────────────────────

@router.post("/messages/{message_id}/attachments", status_code=201)
async def upload_message_attachment(
    message_id: int,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    msg = db.query(Message).filter(Message.id == message_id).first()
    if not msg or msg.sender_id != current_user.id:
        raise HTTPException(status_code=404, detail="Message not found")

    # Check conversation access
    conv = db.query(Conversation).filter(Conversation.id == msg.conversation_id).first()
    if not _user_in_conversation(current_user.id, conv):
        raise HTTPException(status_code=403, detail="Access denied")

    allowed = settings.allowed_image_types_list + settings.allowed_doc_types_list
    result = await save_upload_file(file, "attachments", allowed)

    attachment = MessageAttachment(
        message_id=message_id,
        file_name=result["file_name"],
        original_name=result["original_name"],
        mime_type=result["mime_type"],
        file_size=result["file_size"],
        file_url=result["file_url"],
    )
    db.add(attachment)

    # Update message type
    if msg.text_body:
        msg.message_type = MessageType.mixed
    else:
        msg.message_type = MessageType.attachment

    db.commit()
    db.refresh(attachment)

    from app.schemas.messaging import AttachmentOut
    return AttachmentOut.model_validate(attachment)


@router.post("/conversations/{conversation_id}/messages-with-attachment", response_model=MessageOut, status_code=201)
async def send_message_with_attachment(
    conversation_id: int,
    file: UploadFile = File(...),
    text_body: str | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Send a message with attachment in one request."""
    conv = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if not conv or not _user_in_conversation(current_user.id, conv):
        raise HTTPException(status_code=404, detail="Conversation not found")

    # Determine message type
    has_text = bool(text_body and text_body.strip())
    msg_type = MessageType.mixed if has_text else MessageType.attachment

    msg = Message(
        conversation_id=conversation_id,
        sender_id=current_user.id,
        text_body=text_body if has_text else None,
        message_type=msg_type,
    )
    db.add(msg)
    conv.last_message_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(msg)

    # Save file
    allowed = settings.allowed_image_types_list + settings.allowed_doc_types_list
    result = await save_upload_file(file, "attachments", allowed)

    attachment = MessageAttachment(
        message_id=msg.id,
        file_name=result["file_name"],
        original_name=result["original_name"],
        mime_type=result["mime_type"],
        file_size=result["file_size"],
        file_url=result["file_url"],
    )
    db.add(attachment)

    # Notification
    recipient_id = conv.participant_b_id if conv.participant_a_id == current_user.id else conv.participant_a_id
    notif = Notification(
        user_id=recipient_id,
        type=NotificationType.new_message,
        title="New message",
        body=text_body[:100] if has_text else "[Attachment]",
        reference_type="conversation",
        reference_id=conv.id,
    )
    db.add(notif)
    db.commit()
    db.refresh(msg)

    return MessageOut.model_validate(msg)
