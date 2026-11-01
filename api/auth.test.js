'use strict';
const {before,after,test}=require('node:test');
const assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const path=require('node:path');
let server;
const base='http://127.0.0.1:8082/api';
async function start(port,ttl=60){
 const child=spawn(process.execPath,[path.join(__dirname,'mock-server.js'),'--port',String(port),'--ttl',String(ttl)],{stdio:['ignore','pipe','pipe']});
 await new Promise((resolve,reject)=>{
  const timeout=setTimeout(()=>reject(new Error('API startup timeout')),5000);
  child.stdout.on('data',d=>{if(d.toString().includes('Учебное API')){clearTimeout(timeout);resolve();}});
  child.once('error',reject);child.once('exit',c=>{clearTimeout(timeout);reject(new Error('API exit '+c));});
 });return child;
}
async function req(resource,method='GET',data,token,origin=base){
 const r=await fetch(origin+resource,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},...(data===undefined?{}:{body:JSON.stringify(data)})});
 return {status:r.status,body:r.status===204?null:await r.json()};
}
async function login(username,origin=base){
 const result=await req('/auth/login','POST',{username,password:username+'123'},null,origin);
 assert.equal(result.status,200);return result.body;
}
before(async()=>{server=await start(8082);});
after(()=>server?.kill());
test('защищённые ресурсы недоступны без токена',async()=>{
 assert.equal((await req('/__reset','POST')).status,401);
 for(const endpoint of ['/loans','/loans/1','/readers','/readers/1','/users','/stats']) assert.equal((await req(endpoint)).status,401,endpoint);
});
test('читатель не может менять каталог, роли и выполнять административные операции',async()=>{
 const {accessToken:t}=await login('reader');
 for(const [resource,method,data] of [['/__reset','POST',{}],['/books','POST',{role:'admin'}],['/books/2','PUT',{}],['/books/2','DELETE'],['/books/2?hard=true','DELETE'],['/books/2/restore','POST'],['/users/2/role','PATCH',{role:'admin'}],['/users','GET'],['/stats','GET'],['/loans/1/return','POST']]) assert.equal((await req(resource,method,data,t)).status,403,resource);
});
test('выдачи и данные читателя ограничены владельцем даже при ручном URL',async()=>{
 const {accessToken:t}=await login('reader');
 const all=await req('/loans?readerId=2', 'GET',undefined,t);
 assert.ok(all.body.items.every(l=>l.reader.id===1));
 assert.equal((await req('/loans/2','GET',undefined,t)).status,403);
 assert.equal((await req('/readers/2','GET',undefined,t)).status,403);
 const readers=await req('/readers','GET',undefined,t);
 assert.deepEqual(readers.body.items.map(r=>r.id),[1]);
 assert.equal((await req('/loans/1','PATCH',{readerId:2},t)).status,403);
});
test('читатель продлевает только собственную незакрытую выдачу один раз',async()=>{
 const {accessToken:t}=await login('reader');
 assert.equal((await req('/loans/2/renew','POST',{},t)).status,403);
 assert.equal((await req('/loans/3/renew','POST',{},t)).status,403);
 const result=await req('/loans/1/renew','POST',{},t);
 assert.equal(result.status,200); assert.ok(result.body.renewedAt);
 assert.equal((await req('/loans/1/renew','POST',{},t)).status,409);
 const librarian=await login('librarian');
 assert.equal((await req('/loans/1/return','POST',{},librarian.accessToken)).status,200);
 assert.equal((await req('/loans/1/renew','POST',{},t)).status,409);
});
test('библиотекарь управляет каталогом и выдачами, но не ролями, hard и restore',async()=>{
 const {accessToken:t}=await login('librarian');
 assert.equal((await req('/readers','GET',undefined,t)).body.total,6);
 assert.equal((await req('/loans','GET',undefined,t)).body.total,3);
 const genre=await req('/genres','POST',{name:'Жанр ПР5',description:''},t);
 assert.equal(genre.status,201);
 assert.equal((await req('/genres/'+genre.body.id+'?hard=true','DELETE',undefined,t)).status,403);
 assert.equal((await req('/genres/'+genre.body.id+'/restore','POST',{},t)).status,403);
 assert.equal((await req('/users','GET',undefined,t)).status,403);
 assert.equal((await req('/stats','GET',undefined,t)).status,403);
 assert.equal((await req('/loans/1/renew','POST',{},t)).status,403);
});
test('регистрация проверяет пароль и выдаёт только reader с собственной карточкой',async()=>{
 const input={username:'practice5',fullName:'Читатель ПР5',email:'pr5@example.test',role:'admin'};
 const bad=await req('/auth/register','POST',{...input,password:'Password1'});
 assert.equal(bad.status,422); assert.ok(bad.body.errors.password);
 const good=await req('/auth/register','POST',{...input,password:'Password1!'});
 assert.equal(good.status,201); assert.equal(good.body.role,'reader');
 assert.equal(good.body.password,undefined);assert.equal(good.body.passwordHash,undefined);
 const logged=await req('/auth/login','POST',{username:input.username,password:'Password1!'});
 const cards=await req('/readers','GET',undefined,logged.body.accessToken);
 assert.equal(cards.body.total,1);assert.ok(cards.body.items[0].card.number);
});
test('администратор меняет роль и получает статистику; подмена клиента не даёт прав',async()=>{
 const reader=await login('reader');
 // Simulates UI-only localStorage tampering: the original signed token is unchanged.
 assert.equal((await req('/users','GET',undefined,reader.accessToken)).status,403);
 const admin=await login('admin');
 const users=await req('/users','GET',undefined,admin.accessToken);
 const target=users.body.items.find(u=>u.username==='practice5');
 const change=await req('/users/'+target.id+'/role','PATCH',{role:'librarian'},admin.accessToken);
 assert.equal(change.status,200);assert.equal(change.body.role,'librarian');
 assert.equal((await req('/users/1/role','PATCH',{role:'reader'},admin.accessToken)).status,409);
 const stats=await req('/stats','GET',undefined,admin.accessToken);
 assert.equal(stats.status,200);assert.equal(stats.body.books,20);assert.ok(stats.body.activeLoans>=1);
 const parts=reader.accessToken.split('.');const payload=JSON.parse(Buffer.from(parts[0],'base64url'));
 payload.role='admin';parts[0]=Buffer.from(JSON.stringify(payload)).toString('base64url');
 assert.equal((await req('/users','GET',undefined,parts.join('.'))).status,401);
});
test('истёкший access обновляется; старый refresh отозван, logout запрещает повторное обновление',async()=>{
 const short=await start(8083,1);const origin='http://127.0.0.1:8083/api';
 try{
  const original=await login('reader',origin);
  await new Promise(resolve=>setTimeout(resolve,1200));
  assert.equal((await req('/loans','GET',undefined,original.accessToken,origin)).status,401);
  const fresh=await req('/auth/refresh','POST',{refreshToken:original.refreshToken},null,origin);
  assert.equal(fresh.status,200);assert.notEqual(fresh.body.accessToken,original.accessToken);
  assert.equal((await req('/loans','GET',undefined,fresh.body.accessToken,origin)).status,200);
  assert.equal((await req('/auth/refresh','POST',{refreshToken:original.refreshToken},null,origin)).status,401);
  assert.equal((await req('/auth/logout','POST',{refreshToken:fresh.body.refreshToken},null,origin)).status,204);
  assert.equal((await req('/auth/refresh','POST',{refreshToken:fresh.body.refreshToken},null,origin)).status,401);
 }finally{short.kill();}
});
