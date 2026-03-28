from dataclasses import dataclass

from fastapi import Query


@dataclass
class PaginationParams:
    page: int
    page_size: int

    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size


def get_pagination(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
) -> PaginationParams:
    return PaginationParams(page=page, page_size=page_size)


def paginated_response(items: list, total: int, pagination: PaginationParams) -> dict:
    return {
        "items": items,
        "page": pagination.page,
        "page_size": pagination.page_size,
        "total_items": total,
        "total_pages": (total + pagination.page_size - 1) // pagination.page_size,
    }
