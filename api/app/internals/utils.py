from collections.abc import AsyncIterable


async def alist[T](iterable: AsyncIterable[T]) -> list[T]:
    return [x async for x in iterable]
