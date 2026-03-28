from datetime import datetime
from pydantic import BaseModel, Field


class AttachmentOut(BaseModel):
    id: int
    file_name: str
    original_name: str
    mime_type: str
    file_size: int
    file_url: str

    class Config:
        from_attributes = True


class MessageOut(BaseModel):
    id: int
    conversation_id: int
    sender_id: int
    text_body: str | None = None
    message_type: str
    is_read: bool
    sent_at: datetime
    attachments: list[AttachmentOut] = []

    class Config:
        from_attributes = True


class ConversationParticipant(BaseModel):
    id: int
    full_name: str
    profile_image_url: str | None = None

    class Config:
        from_attributes = True


class ConversationOut(BaseModel):
    id: int
    listing_id: int | None = None
    participant_a: ConversationParticipant
    participant_b: ConversationParticipant
    last_message_at: datetime | None = None
    last_message_preview: str | None = None
    unread_count: int = 0
    created_at: datetime

    class Config:
        from_attributes = True


class CreateConversationRequest(BaseModel):
    listing_id: int
    recipient_id: int
    initial_message: str | None = Field(None, max_length=2000)


class SendMessageRequest(BaseModel):
    text_body: str | None = Field(None, max_length=2000)
