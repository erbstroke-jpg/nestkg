from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.user import User
from app.models.report import Report, ReportStatus
from app.schemas.report import ReportCreateRequest, ReportOut
from app.dependencies.auth import get_current_user
from app.dependencies.pagination import get_pagination, PaginationParams, paginated_response

router = APIRouter(prefix="/reports", tags=["Reports"])


@router.post("", response_model=ReportOut, status_code=status.HTTP_201_CREATED)
def create_report(
    req: ReportCreateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    # Prevent self-reporting
    if req.target_type == "user" and req.target_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot report yourself")

    report = Report(
        reporter_user_id=current_user.id,
        target_type=req.target_type,
        target_id=req.target_id,
        reason_code=req.reason_code,
        reason_text=req.reason_text,
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return ReportOut.model_validate(report)


@router.get("/my")
def my_reports(
    pagination: PaginationParams = Depends(get_pagination),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    query = (
        db.query(Report)
        .filter(Report.reporter_user_id == current_user.id)
        .order_by(Report.created_at.desc())
    )
    total = query.count()
    items = query.offset(pagination.offset).limit(pagination.page_size).all()

    return paginated_response(
        [ReportOut.model_validate(r) for r in items],
        total,
        pagination,
    )
