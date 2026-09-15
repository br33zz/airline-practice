# Контракт учебного API Авиакомпания

Базовый адрес: `http://localhost:8080/api`. Формат обмена — JSON, кодировка UTF-8.

## Ресурсы

Доступны ресурсы `flights`, `aircraft`, `pilots`, `services`, `passengers`.

Для каждого ресурса поддерживаются:

- `GET /api/{resource}` — список;
- `GET /api/{resource}/{id}` — одна запись;
- `POST /api/{resource}` — создание;
- `PUT /api/{resource}/{id}` — изменение;
- `DELETE /api/{resource}/{id}` — логическое удаление;
- `DELETE /api/{resource}/{id}?hard=true` — физическое удаление;
- `POST /api/{resource}/{id}/restore` — восстановление;
- `POST /api/{resource}/bulk-delete` с телом `{ "ids": [1, 2] }` — множественное удаление.

Параметры списка: `search`, `filter`, `sort=field,asc`, `page`, `size`, `includeDeleted`.
Ответ списка: `{ "items": [], "page": 1, "size": 10, "total": 0, "totalPages": 1 }`.

## Ошибки

- `401` — отсутствует токен;
- `404` — запись не найдена;
- `409` — конфликт связей;
- `422` — ошибки полей в объекте `errors`;
- `500` — ошибка сервера.

Для изменяющих запросов используется `Authorization: Bearer airline-admin-token`. Токен выдаёт `POST /api/auth/login` для `admin/admin123`.

Служебные параметры `?__delay=1500` и `?__fail=500` позволяют проверить загрузку и ошибку. `GET /api/__health` проверяет доступность сервера, `POST /api/__reset` восстанавливает исходные данные.
