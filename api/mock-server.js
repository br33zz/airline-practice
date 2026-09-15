const http = require('http');
const { URL } = require('url');

const args = process.argv.slice(2);
const option = (name, fallback) => {
  const index = args.indexOf(name);
  return index >= 0 && args[index + 1] ? args[index + 1] : fallback;
};
const PORT = Number(option('--port', '8080'));
const ORIGIN = option('--origin', 'http://localhost:5555');
const COLLECTIONS = ['flights', 'aircraft', 'pilots', 'services', 'passengers'];
let db;

function seed() {
  db = { flights: [], aircraft: [], pilots: [], services: [], passengers: [] };
  const add = (collection, row) => {
    const id = db[collection].length + 1;
    db[collection].push({ id, ...row, deletedAt: null });
    return id;
  };
  const aircraft = [
    ['RA-73101', 'Airbus A320-200', 'A320', 180],
    ['RA-73312', 'Boeing 737-800', 'B737', 189],
    ['RA-89120', 'Sukhoi Superjet 100', 'SSJ100', 98],
    ['RA-73405', 'Airbus A321neo', 'A320', 220],
    ['RA-73630', 'Boeing 737 MAX 8', 'B737', 178],
    ['RA-89147', 'Sukhoi Superjet New', 'SSJ100', 103],
  ];
  for (const [registrationNumber, model, type, capacity] of aircraft) {
    add('aircraft', { registrationNumber, model, type, capacity });
  }
  const names = ['Иванов Алексей', 'Петров Михаил', 'Соколов Андрей', 'Орлов Максим', 'Волков Сергей', 'Морозов Павел'];
  const types = ['A320', 'B737', 'SSJ100'];
  for (let i = 0; i < 12; i++) {
    add('pilots', {
      fullName: `${names[i % names.length]} ${Math.floor(i / 6) + 1}`,
      licenseNumber: `PL-${4100 + i}`,
      qualification: types[i % types.length],
      experienceYears: 4 + i,
    });
  }
  const serviceRows = [
    ['Питание', 'Горячее питание на борту', 1200],
    ['Багаж 23 кг', 'Одно место зарегистрированного багажа', 2500],
    ['Выбор места', 'Предварительный выбор места', 650],
    ['Бизнес-зал', 'Доступ в зал ожидания', 3200],
    ['Приоритетная посадка', 'Посадка вне общей очереди', 900],
    ['Спортивный багаж', 'Перевозка спортивного инвентаря', 2800],
    ['Домашнее животное', 'Перевозка животного в салоне', 4000],
    ['Страхование', 'Страхование поездки', 750],
  ];
  for (const [name, description, price] of serviceRows) {
    add('services', { name, description, price });
  }
  const destinations = ['Сочи', 'Казань', 'Санкт-Петербург', 'Екатеринбург', 'Минск', 'Астана'];
  const statuses = ['По расписанию', 'Посадка', 'Задержан'];
  const start = Date.UTC(2026, 8, 10, 6, 30);
  for (let i = 0; i < 18; i++) {
    const aircraftId = i % 6 + 1;
    const type = db.aircraft[aircraftId - 1].type;
    const qualified = db.pilots.filter((pilot) => pilot.qualification === type);
    add('flights', {
      number: `SU ${310 + i}`,
      destination: destinations[i % destinations.length],
      departure: new Date(start + i * 3 * 3600000).toISOString(),
      status: statuses[i % statuses.length],
      seats: 70 + i * 3,
      aircraftId,
      pilotIds: [qualified[i % qualified.length].id],
      serviceIds: [1, 2, 3 + i % 5],
    });
  }
  const passengerNames = ['Анна Петрова', 'Иван Сидоров', 'Мария Кузнецова', 'Алексей Смирнов', 'Ольга Волкова'];
  const countries = ['Россия', 'Беларусь', 'Казахстан'];
  for (let i = 0; i < 15; i++) {
    add('passengers', {
      fullName: `${passengerNames[i % passengerNames.length]} ${Math.floor(i / 5) + 1}`,
      passport: `${4500 + i} ${120000 + i}`,
      country: countries[i % countries.length],
      email: `passenger${i + 1}@example.ru`,
      ticket: {
        number: `TKT-${10001 + i}`,
        flightId: i % 18 + 1,
        seat: `${i % 28 + 1}${String.fromCharCode(65 + i % 6)}`,
        fareClass: i % 5 === 0 ? 'Бизнес' : 'Эконом',
        issuedAt: new Date(Date.UTC(2026, 8, 1 + i)).toISOString(),
      },
    });
  }
}

function cors(res) {
  res.setHeader('Access-Control-Allow-Origin', ORIGIN);
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.setHeader('Access-Control-Max-Age', '86400');
}

function send(res, status, payload) {
  cors(res);
  if (status === 204) {
    res.writeHead(204);
    return res.end();
  }
  const text = JSON.stringify(payload);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(text),
  });
  res.end(text);
}

const fail = (res, status, message) => send(res, status, { message });

async function body(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8'));
  } catch (_) {
    return null;
  }
}

function authorized(req) {
  return req.headers.authorization === 'Bearer airline-admin-token';
}

function validate(collection, value, id) {
  const errors = {};
  const required = (key, label) => {
    if (!String(value[key] ?? '').trim()) errors[key] = `Укажите ${label}`;
  };
  if (collection === 'flights') {
    required('number', 'номер рейса');
    required('destination', 'направление');
    if (db.flights.some((x) => x.id !== id && !x.deletedAt && x.number.replaceAll(' ', '').toLowerCase() === String(value.number ?? '').replaceAll(' ', '').toLowerCase())) {
      errors.number = 'Рейс с таким номером уже существует';
    }
    if (!db.aircraft.some((x) => x.id === Number(value.aircraftId) && !x.deletedAt)) errors.aircraftId = 'Самолёт не найден';
    if (!Array.isArray(value.pilotIds) || value.pilotIds.length === 0) errors.pilotIds = 'Выберите хотя бы одного пилота';
  } else if (collection === 'aircraft') {
    required('registrationNumber', 'регистрационный номер');
    required('model', 'модель');
    required('type', 'тип самолёта');
    if (Number(value.capacity) < 1) errors.capacity = 'Вместимость должна быть положительной';
  } else if (collection === 'pilots') {
    required('fullName', 'ФИО');
    required('licenseNumber', 'номер лицензии');
    required('qualification', 'квалификацию');
  } else if (collection === 'services') {
    required('name', 'название');
    if (Number(value.price) < 0) errors.price = 'Стоимость не может быть отрицательной';
  } else if (collection === 'passengers') {
    required('fullName', 'ФИО');
    required('email', 'электронную почту');
    if (db.passengers.some((x) => x.id !== id && !x.deletedAt && x.email.toLowerCase() === String(value.email ?? '').toLowerCase())) {
      errors.email = 'Пассажир с такой почтой уже существует';
    }
    if (!value.ticket || !db.flights.some((x) => x.id === Number(value.ticket.flightId) && !x.deletedAt)) errors.ticketFlightId = 'Рейс не найден';
  }
  return errors;
}

function searchable(collection, row) {
  if (collection === 'flights') return `${row.number} ${row.destination} ${row.status}`;
  if (collection === 'aircraft') return `${row.registrationNumber} ${row.model} ${row.type}`;
  if (collection === 'pilots') return `${row.fullName} ${row.licenseNumber} ${row.qualification}`;
  if (collection === 'services') return `${row.name} ${row.description}`;
  return `${row.fullName} ${row.passport} ${row.country} ${row.email} ${row.ticket?.number ?? ''}`;
}

function filterValue(collection, row) {
  if (collection === 'flights') return row.status;
  if (collection === 'aircraft') return row.type;
  if (collection === 'pilots') return row.qualification;
  if (collection === 'services') return row.price === 0 ? 'Бесплатно' : 'Платно';
  return row.country;
}

function list(collection, query) {
  let rows = db[collection].filter((row) => query.includeDeleted === 'true' || !row.deletedAt);
  if (query.search) {
    const needle = query.search.toLowerCase();
    rows = rows.filter((row) => searchable(collection, row).toLowerCase().includes(needle));
  }
  if (query.filter) rows = rows.filter((row) => filterValue(collection, row) === query.filter);
  const [field, direction = 'asc'] = String(query.sort || 'id,asc').split(',');
  rows.sort((a, b) => {
    const av = a[field] ?? '';
    const bv = b[field] ?? '';
    const result = typeof av === 'number' && typeof bv === 'number'
      ? av - bv
      : String(av).localeCompare(String(bv), 'ru');
    return direction === 'desc' ? -result : result;
  });
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(100, Math.max(1, Number(query.size) || 10));
  const total = rows.length;
  return { items: rows.slice((page - 1) * size, page * size), page, size, total, totalPages: Math.max(1, Math.ceil(total / size)) };
}

async function handle(req, res, url) {
  const method = req.method.toUpperCase();
  const path = url.pathname.replace(/\/+$/, '') || '/';
  const query = Object.fromEntries(url.searchParams.entries());
  if (query.__fail) return fail(res, Number(query.__fail), 'Ошибка вызвана параметром __fail');
  if (path === '/api/__health' && method === 'GET') return send(res, 200, { status: 'ok', time: new Date().toISOString() });
  if (path === '/api/__reset' && method === 'POST') {
    seed();
    return send(res, 200, { message: 'Исходные данные восстановлены' });
  }
  if (path === '/api/auth/login' && method === 'POST') {
    const value = await body(req);
    if (value?.username === 'admin' && value?.password === 'admin123') {
      return send(res, 200, { accessToken: 'airline-admin-token', expiresIn: 3600, user: { id: 1, role: 'admin' } });
    }
    return fail(res, 401, 'Неверный логин или пароль');
  }
  const bulk = path.match(/^\/api\/([a-z]+)\/bulk-delete$/);
  if (bulk && method === 'POST') {
    const collection = bulk[1];
    if (!COLLECTIONS.includes(collection)) return fail(res, 404, 'Ресурс не найден');
    if (!authorized(req)) return fail(res, 401, 'Требуется аутентификация');
    const value = await body(req);
    const ids = Array.isArray(value?.ids) ? value.ids.map(Number) : [];
    if (!ids.length) return send(res, 422, { message: 'Ошибка валидации', errors: { ids: 'Выберите записи' } });
    let deleted = 0;
    for (const row of db[collection]) {
      if (ids.includes(row.id) && !row.deletedAt) {
        row.deletedAt = new Date().toISOString();
        deleted++;
      }
    }
    return send(res, 200, { deleted });
  }
  const match = path.match(/^\/api\/([a-z]+)(?:\/(\d+))?(?:\/(restore))?$/);
  if (!match || !COLLECTIONS.includes(match[1])) return fail(res, 404, 'Ресурс не найден');
  const collection = match[1];
  const id = match[2] ? Number(match[2]) : null;
  const action = match[3];
  if (method === 'GET' && id === null) return send(res, 200, list(collection, query));
  if (method === 'GET' && id !== null) {
    const found = db[collection].find((row) => row.id === id && (query.includeDeleted === 'true' || !row.deletedAt));
    return found ? send(res, 200, found) : fail(res, 404, 'Запись не найдена');
  }
  if (!authorized(req)) return fail(res, 401, 'Требуется аутентификация');
  if (action === 'restore' && method === 'POST') {
    const found = db[collection].find((row) => row.id === id);
    if (!found) return fail(res, 404, 'Запись не найдена');
    found.deletedAt = null;
    return send(res, 200, found);
  }
  if (method === 'POST' && id === null) {
    const value = await body(req);
    if (!value) return fail(res, 400, 'Некорректный JSON');
    const errors = validate(collection, value, null);
    if (Object.keys(errors).length) return send(res, 422, { message: 'Ошибка валидации', errors });
    const nextId = db[collection].reduce((max, row) => Math.max(max, row.id), 0) + 1;
    const created = { id: nextId, ...value, deletedAt: null };
    db[collection].push(created);
    return send(res, 201, created);
  }
  const index = db[collection].findIndex((row) => row.id === id);
  if (index < 0) return fail(res, 404, 'Запись не найдена');
  if (method === 'PUT') {
    const value = await body(req);
    if (!value) return fail(res, 400, 'Некорректный JSON');
    const errors = validate(collection, value, id);
    if (Object.keys(errors).length) return send(res, 422, { message: 'Ошибка валидации', errors });
    db[collection][index] = { id, ...value, deletedAt: db[collection][index].deletedAt };
    return send(res, 200, db[collection][index]);
  }
  if (method === 'DELETE') {
    const hard = query.hard === 'true';
    if (collection === 'aircraft') {
      const linked = db.flights.filter((flight) => flight.aircraftId === id && !flight.deletedAt).length;
      if (linked) return fail(res, 409, `Самолёт используется активными рейсами: ${linked}`);
    }
    if (hard) db[collection].splice(index, 1);
    else db[collection][index].deletedAt = new Date().toISOString();
    return send(res, 204);
  }
  return fail(res, 405, 'Метод не поддерживается');
}

seed();
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);
  if (req.method === 'OPTIONS') {
    cors(res);
    res.writeHead(204);
    return res.end();
  }
  const delay = Math.min(10000, Math.max(0, Number(url.searchParams.get('__delay')) || 0));
  if (delay) await new Promise((resolve) => setTimeout(resolve, delay));
  const started = Date.now();
  try {
    await handle(req, res, url);
  } catch (error) {
    console.error(error);
    if (!res.headersSent) fail(res, 500, 'Внутренняя ошибка сервера');
  }
  console.log(`${req.method.padEnd(6)} ${url.pathname}${url.search} -> ${res.statusCode} (${Date.now() - started} мс)`);
});
server.listen(PORT, () => {
  console.log(`Учебное API «Авиакомпания»: http://localhost:${PORT}/api`);
  console.log(`Разрешённый источник: ${ORIGIN}`);
  console.log('Учётная запись: admin/admin123');
});
