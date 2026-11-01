'use strict';
const { before, after, test } = require('node:test');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const path = require('node:path');
const base = 'http://127.0.0.1:8081/api';
let server, token;
async function request(resource, method = 'GET', data, authorization = token) {
  const response = await fetch(base + resource, {
    method, headers: { 'Content-Type': 'application/json',
      ...(authorization ? { Authorization: 'Bearer ' + authorization } : {}) },
    ...(data !== undefined ? { body: JSON.stringify(data) } : {}),
  });
  return { status: response.status, body: response.status === 204 ? null : await response.json() };
}
before(async () => {
  server = spawn(process.execPath, [path.join(__dirname, 'mock-server.js'),
    '--port', '8081', '--origin', 'http://localhost:5555'], { stdio: ['ignore','pipe','pipe'] });
  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => reject(new Error('API did not start')), 5000);
    server.stdout.on('data', (data) => {
      if (data.toString().includes('Учебное API')) { clearTimeout(timeout); resolve(); }
    });
    server.once('exit', (code) => { clearTimeout(timeout); reject(new Error('API exited: ' + code)); });
    server.once('error', reject);
  });
  const login = await request('/auth/login', 'POST', { username:'admin', password:'admin123' }, null);
  assert.equal(login.status, 200);
  token = login.body.accessToken;
});
after(() => server?.kill());

test('health и CORS preflight', async () => {
  assert.equal((await request('/__health')).body.status, 'ok');
  const response = await fetch(base + '/books', { method:'OPTIONS', headers:{
    Origin:'http://localhost:5555','Access-Control-Request-Method':'PUT',
    'Access-Control-Request-Headers':'Content-Type, Authorization',
  }});
  assert.equal(response.status,204);
  assert.equal(response.headers.get('access-control-allow-origin'),'http://localhost:5555');
  assert.match(response.headers.get('access-control-allow-headers'), /Authorization/);
});

test('все пять сущностей: создание, чтение, изменение, soft/bulk, restore, hard', async () => {
  const fixtures = {
    books:{ title:'Книга тест API',isbn:'9780000009991',year:2020,pages:100,
      publisherId:1,authorIds:[1],genreIds:[1],copiesTotal:2 },
    authors:{fullName:'Автор API',birthYear:1980,country:'Россия'},
    genres:{name:'Жанр API',description:'Проверка'},
    publishers:{name:'Издательство API',city:'Казань',foundedYear:2020},
    readers:{fullName:'Читатель API',email:'api-test@example.test',phone:'+7 900 123 4567',
      card:{number:'API-TEST-1',issuedAt:'2025-01-01T00:00:00Z',expiresAt:'2030-01-01T00:00:00Z'}},
  };
  for (const [section, input] of Object.entries(fixtures)) {
    const created = await request('/'+section,'POST',input);
    assert.equal(created.status,201,section);
    const id = created.body.id;
    assert.equal((await request('/'+section+'/'+id)).body.id,id);
    const field = section === 'books' ? 'title' : ['genres','publishers'].includes(section) ? 'name' : 'fullName';
    input[field] += ' изменён';
    assert.equal((await request('/'+section+'/'+id,'PUT',input)).body[field],input[field]);
    if(section === 'readers') {
      assert.equal(created.body.card.number,'API-TEST-1');
      assert.equal((await request('/readers/'+id)).body.card.number,'API-TEST-1');
    }
    assert.equal((await request('/'+section+'/'+id,'DELETE')).status,204);
    assert.equal((await request('/'+section+'/'+id)).status,404);
    assert.equal((await request('/'+section+'/'+id+'/restore','POST')).status,200);
    assert.equal((await request('/'+section+'/bulk-delete','POST',{ids:[id]})).body.deleted,1);
    assert.equal((await request('/'+section+'/'+id+'/restore','POST')).status,200);
    assert.equal((await request('/'+section+'/'+id+'?hard=true','DELETE')).status,204);
    if (section === 'readers') {
      const reused = await request('/readers','POST',{...input,email:'reused@example.test'});
      assert.equal(reused.status,201,'Номер билета освобождается после физического удаления');
      await request('/readers/'+reused.body.id+'?hard=true','DELETE');
    }
  }
});

test('поиск, страницы и дополнительные фильтры выполняет сервер', async () => {
  const first = await request('/books?page=1&size=10&sort=title,asc');
  const second = await request('/books?page=2&size=10&sort=title,asc');
  assert.equal(first.body.items.length,10);
  assert.notEqual(first.body.items[0].id,second.body.items[0].id);
  const authors = await request('/authors?filter='+encodeURIComponent('США'));
  assert.ok(authors.body.items.length > 0);
  assert.ok(authors.body.items.every((row)=>row.country === 'США'));
  const publishers = await request('/publishers?filter='+encodeURIComponent('Москва'));
  assert.ok(publishers.body.items.every((row)=>row.city === 'Москва'));
  const unused = await request('/genres?filter=unused');
  assert.ok(unused.body.total > 0);
  const readers = await request('/readers?filter=valid&sort=expiresAt,desc');
  assert.ok(readers.body.items.every((row)=>row.card.expiresAt.slice(0,10) >= new Date().toISOString().slice(0,10)));
  assert.equal((await request('/readers?search=RC-000001')).body.total,1);
  const options = await request('/publishers/3/options');
  assert.equal(options.status,200);
  assert.equal(options.body.hasBooks,true);
  assert.ok(options.body.authorIds.length > 0);
});

test('422 для дубликата ISBN и 409 для отсутствующих экземпляров', async () => {
  const existing = (await request('/books?page=1&size=10')).body.items[0];
  const input = {title:'Проверка конфликта',isbn:existing.isbn,year:2020,pages:100,
    publisherId:1,authorIds:[1],genreIds:[1],copiesTotal:1};
  const invalid = await request('/books','POST',input);
  assert.equal(invalid.status,422);
  assert.ok(invalid.body.errors.isbn);
  const created = await request('/books','POST',{...input,isbn:'9780000009992'});
  const issue = await request('/loans','POST',{bookId:created.body.id,readerId:1,days:14});
  assert.equal(issue.status,201);
  const conflict = await request('/loans','POST',{bookId:created.body.id,readerId:1,days:14});
  assert.equal(conflict.status,409);
  assert.match(conflict.body.message,/Нет свободных/);
  assert.equal((await request('/books/'+created.body.id+'?hard=true','DELETE')).status,409);
  assert.equal((await request('/loans/'+issue.body.id+'/return','POST')).status,200);
  assert.equal((await request('/books/'+created.body.id+'?hard=true','DELETE')).status,204);
  assert.equal((await request('/publishers/1','DELETE')).status,409);
});
