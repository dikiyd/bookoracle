const $=id=>document.getElementById(id);
const ENDPOINT='https://book-oracle-playtest-receiver.coexistence-ru.chatgpt.site/api/sessions';
let books=[], version='oracle-web-2026-10-28', session=null, currentQuestion='', selectedBook='', startAt=0, lastReport=null;
const pending=new Map();
const normalize=s=>s.toLocaleLowerCase('ru').replaceAll('ё','е').trim();
const status=t=>$('send-status').textContent=t;
function draft(mode){startAt=performance.now();return {id:crypto.randomUUID(),version,mode,outcome:'abandoned',bookId:'',bookTitle:'',character:'',comment:'',events:[],unclear:[],consent:$('consent').checked};}
function event(type,extra={}){if(session&&session.events.length<300)session.events.push({type,ms:Math.round(performance.now()-startAt),...extra});}
function report(){if(!session)return null;const {consent,...body}=session;return structuredClone(body);}
async function send(body){
  lastReport=body;$('download').hidden=false;
  if(!session?.consent){status('Отправка выключена. Свой отчёт можно скачать.');return;}
  pending.set(body.id,body);
  try{const response=await fetch(ENDPOINT,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(15000)});
    if(!response.ok)throw new Error('HTTP '+response.status);
    const result=await response.json();if(!result.ok||result.id!==body.id)throw new Error('Unexpected response');
    pending.delete(body.id);status('Результат сохранён. Спасибо — он поможет улучшить Оракула.');
  }catch{status('Не удалось отправить результат. Он сохранён в этой вкладке: повторите отправку или скачайте отчёт.');}
  $('retry').hidden=pending.size===0;
}
function openFeedback(){if(!session){status('Сначала начните игру.');return;}
  $('book-title').value=session.bookTitle;$('character').value=session.character;$('outcome').value=session.outcome==='confirmed'?'confirmed':'missed';
  $('comment').value=session.comment;selectedBook=session.bookId;$('feedback-status').textContent='';$('book-options').replaceChildren();$('feedback').showModal();}
window.addEventListener('message',e=>{
  if(e.source!==$('game').contentWindow||e.origin!==location.origin||e.data?.channel!=='book-oracle')return;
  const d=e.data;
  if(d.type==='start'){
    if(session&&!session.finished&&session.events.length>1){const old=report();send(old);}
    session=draft(d.mode);currentQuestion='';event('start');status('');return;
  }
  if(!session)return;
  if(d.type==='question'){currentQuestion=d.question;event('question',{question:d.question});$('question-status').textContent='';$('unclear').disabled=false;}
  else if(d.type==='answer')event('answer',{question:d.question,value:d.value});
  else if(['undo','reject','guess','shortlist','no_match'].includes(d.type)){event(d.type,d.ids?{ids:d.ids}:{});currentQuestion='';}
  else if(d.type==='confirmed'){event('confirmed',{ids:d.ids});Object.assign(session,{outcome:'confirmed',bookId:d.bookId,bookTitle:d.bookTitle,character:d.character});openFeedback();}
  else if(d.type==='feedback'){event('feedback');openFeedback();}
  else if(d.type==='home'&&!session.finished){event('home');openFeedback();}
});
$('play').onclick=()=>{ $('welcome').hidden=true;$('play-area').hidden=false;if(!$('game').getAttribute('src'))$('game').src='game/index.html';$('play-area').scrollIntoView({behavior:'smooth'});};
$('welcome-back').onclick=()=>{if(session&&!session.finished)openFeedback();$('welcome').hidden=false;$('play-area').hidden=true;};
$('feedback-open').onclick=openFeedback;
$('unclear').onclick=()=>{if(session&&currentQuestion){if(!session.unclear.includes(currentQuestion))session.unclear.push(currentQuestion);$('question-status').textContent='Отмечено. Продолжайте отвечать.';$('unclear').disabled=true;}else $('question-status').textContent='Отметка доступна, когда Оракул задаёт вопрос.';};
for(const b of document.querySelectorAll('[data-close]'))b.onclick=()=>$(b.dataset.close).close();
function matches(query){const q=normalize(query);return books.filter(b=>normalize(b.title+' '+b.author+' '+(b.aliases||[]).join(' ')).includes(q));}
$('book-title').oninput=()=>{selectedBook='';const options=$('book-options');options.replaceChildren();const query=$('book-title').value;if(query.length<2)return;
  for(const b of matches(query).slice(0,6)){const button=document.createElement('button');button.type='button';button.textContent=b.title+' — '+b.author;button.onclick=()=>{selectedBook=b.id;$('book-title').value=b.title;options.replaceChildren();};options.append(button);}};
$('feedback-form').onsubmit=async e=>{e.preventDefault();if(!session)return;
  if(!$('book-title').value.trim()&&!$('character').value.trim()){$('feedback-status').textContent='Укажите хотя бы книгу или героя.';return;}
  Object.assign(session,{bookId:selectedBook,bookTitle:$('book-title').value.trim(),character:$('character').value.trim(),outcome:$('outcome').value,comment:$('comment').value.trim()});
  // A submitted report is immutable server-side; a later edited review is a new report.
  if(session.finished)session.id=crypto.randomUUID();
  const body=report();delete body.finished;session.finished=true;$('feedback').close();await send(body);
};
$('retry').onclick=async()=>{for(const body of [...pending.values()])await send(body);};
$('download').onclick=()=>{const blob=new Blob([JSON.stringify([...pending.values()].length?[...pending.values()]:[lastReport],null,2)],{type:'application/json'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download='oracle-feedback.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
function renderCatalog(){const results=matches($('catalog-search').value);$('catalog-count').textContent=`Найдено: ${results.length}. Показаны первые ${Math.min(60,results.length)}.`;const holder=$('catalog-results');holder.replaceChildren();for(const b of results.slice(0,60)){const row=document.createElement('article');row.className='book-row';const title=document.createElement('h3');title.textContent=b.title;const author=document.createElement('p');author.textContent=b.author+(b.year?' · '+b.year:'');const badge=document.createElement('span');badge.className='badge';badge.textContent=b.coverage==='metadata_only'?'Базовая карточка · сюжет ещё не разобран':'Есть в игровом наборе';row.append(title,author,badge);if(b.source?.startsWith('https://www.wikidata.org/wiki/Q')){const source=document.createElement('a');source.href=b.source;source.target='_blank';source.rel='noopener';source.textContent=' Источник';source.className='small';row.append(source);}holder.append(row);}}
for(const id of ['catalog-open','catalog-open-bottom'])$(id).onclick=()=>{renderCatalog();$('catalog').showModal();};
$('catalog-search').oninput=renderCatalog;
Promise.all([fetch('catalog.json').then(r=>{if(!r.ok)throw Error();return r.json();}),fetch('version.json').then(r=>r.json())]).then(([catalog,v])=>{books=catalog.books;version=v.version;$('version').textContent=version;$('catalog-stats').textContent=`${books.length.toLocaleString('ru')} книг в справочнике. ${catalog.stats.game_catalog.toLocaleString('ru')} — в текущем игровом наборе, ${catalog.stats.metadata_only.toLocaleString('ru')} — базовые карточки для дальнейшего наполнения.`;}).catch(()=>{$('catalog-stats').textContent='Каталог не загрузился. Обновите страницу, чтобы повторить.';});
window.addEventListener('beforeunload',e=>{if(pending.size){e.preventDefault();e.returnValue='';}});
