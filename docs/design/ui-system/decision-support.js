/* Read-only decision projections for illustrative data. Not a second Godot ruleset. */
const equipmentDefinitions = Object.freeze({
  sabre: {family:'blade',weight:1.8,damage:29,impact:24,lightStamina:12},
  travel_blade: {family:'blade',weight:1.1,damage:25,impact:18,lightStamina:9},
  bow: {family:'bow',weight:2.1,damage:25,range:18,ammo:'箭矢'},
  shield: {family:'shield',weight:3,block:45,stability:18,recovery:-5},
  coat: {family:'armor',weight:3.2,defense:8,stability:12},
  spare_coat: {family:'armor',weight:3.5,defense:10,stability:14}
});
const statDefinitions = {
  damage:{title:'物理伤害',unit:'',good:1},impact:{title:'稳定削减',unit:'',good:1},
  lightStamina:{title:'轻击体力',unit:'',good:-1},weight:{title:'重量',unit:'',good:-1},
  defense:{title:'物理减伤',unit:'%',good:1},stability:{title:'稳定抗性',unit:'',good:1},
  block:{title:'格挡减伤',unit:'%',good:1},recovery:{title:'体力回复',unit:'%',good:1},
  range:{title:'有效射程',unit:'步',good:1}
};
const preparationDefinitions = {
  repair:{name:'为压印台留布料',kind:'supply',needs:{cloth:1},desc:'保留材料是整理意图，不锁住或预扣实物。'},
  rag:{name:'再制造火抹布',kind:'craft',recipe:'rag',desc:'实际加工成功后才计入本次完成。'},
  stone:{name:'再制造火石',kind:'craft',recipe:'stone',desc:'制作阵材不授予施法资格。'},
  supplies:{name:'一程食水',kind:'supply',needs:{ration:2,water:2},desc:'只检查身上可用数量，不从远处仓库消费。'}
};
const ruleGlossary = {
  stability:{title:'稳定与失衡',body:'伤害和稳定削减是不同维度。削减稳定不等于造成同量生命伤害；是否失衡由共同命中规则决定。',note:'本原型只展示装备样例值，不模拟命中或敌人稳定。'},
  stamina:{title:'体力与战斗承诺',body:'攻击、重击、防御和闪避有各自费用与阶段。费用更低是取舍之一，不能仅凭面板伤害排出综合战力。',note:'预览不会攻击、支付体力或消耗武器涂层。'},
  load:{title:'重量与可访问来源',body:'身上物品计入负重。镇中寄存箱属于已知来源，不能在野外远程取用。不同来源的容量与位置不能用聚合数字抹掉。',note:'原型容量是样例，不是正式平衡。100项夹具会显式提高样例上限。'},
  source:{title:'动作、形式与真实来源',body:'同一基础动作可以有不同形式。选择只改变准备，仍需手动执行并重验资格、位置、具体瓶、材料和总费用。失效不能偷偷换成另一种形式。',note:'普通喷剂不需要魔力；主动法术需要觉醒。'},
  statuses:{title:'人物、武器与地面',body:'异常积累尚未等于状态生效；人物状态、具体武器涂层和地面阵能是三种归属。它们的计时与消耗应分别展示。',note:'复合状态面板是明确的静态样例，不模拟实际AI或持续效果。'}
};

function equipmentFacts(i) {
  const f=equipmentDefinitions[i?.definition];
  if(!f) return null;
  return {...f,...(f.damage!==undefined?{damage:f.damage+(i.upgrade||0)}:{})};
}
function equipmentStats(i) {
  const f=equipmentFacts(i);
  if(!f) return i.stats;
  const order=['damage','impact','lightStamina','defense','block','stability','recovery','range'];
  return order.filter(k=>f[k]!==undefined).map(k=>[statDefinitions[k].title,String(f[k])+statDefinitions[k].unit])
    .concat(f.ammo?[['弹药',f.ammo+' ×1']]:[]);
}
function preparationRows() {
  const aggregate={};
  for(const g of state.goals) {
    const def=preparationDefinitions[g.id];
    const remaining=def.kind==='craft'?Math.max(0,g.amount-g.done):g.amount;
    const needs=def.kind==='craft'?recipeCosts(def.recipe):def.needs;
    for(const [id,qty] of Object.entries(needs)) {
      if(!remaining) continue;
      const row=aggregate[id] ||= {id,need:0,goals:[]};
      row.need+=qty*remaining;row.goals.push(def.name);
    }
  }
  return Object.values(aggregate).map(r=>({...r,have:available(r.id),missing:Math.max(0,r.need-available(r.id)),elsewhere:items.filter(i=>i.definition===r.id&&i.owner==='stash'&&i.qty>0).reduce((n,i)=>n+i.qty,0)}));
}
function protectedReasons(i) {
  if(!i) return ['来源不存在'];
  const reasons=[];
  if(i.equipped) reasons.push('已穿戴');
  if(i.type==='quest'||i.id==='coin') reasons.push('重要实物');
  if(state.organization[i.id]?.favorite) reasons.push('收藏');
  if(Object.values(bindings).some(b=>b.kind==='item'&&b.id===i.id)) reasons.push('快捷来源');
  if(preparationRows().some(r=>r.id===i.definition&&r.need>0)) reasons.push('准备所需');
  return reasons;
}
function safeForBatch(i) {return owned(i)&&!protectedReasons(i).length;}
function organizeBadges(i) {
  const m=state.organization[i.id]||{},reasons=protectedReasons(i);
  return [m.favorite?'★ 收藏':'',m.ware?'待售':'',reasons.includes('快捷来源')?'已绑定':'',reasons.includes('准备所需')?'准备所需':''].filter(Boolean).join(' · ');
}
function markItem(id,kind) {
  const i=getItem(id);if(!owned(i)) return;
  if(kind==='ware'&&(i.type==='quest'||i.id==='coin')) {toast('任务记录与钱币不能标为待售','error');return;}
  const meta=state.organization[id] ||= {};
  meta[kind]=!meta[kind];
}
function completePreparation(id,n) {
  const goal=state.goals.find(g=>g.id===id);
  if(goal&&preparationDefinitions[id].kind==='craft') goal.done=Math.min(goal.amount,goal.done+n);
}
function pinGoal(id) {
  if(state.goals.some(g=>g.id===id)) {state.goals=state.goals.filter(g=>g.id!==id);return true;}
  if(state.goals.length>=3) {toast('最多固定3个准备目标，请先移除一项','error');return false;}
  state.goals.push({id,amount:1,done:0});return true;
}
function comparisonProjection(i) {
  const old=equipped(i.slot),next=equipmentFacts(i),before=equipmentFacts(old);
  if(i.equipped) return '<p>当前已穿戴这件装备。</p>';
  if(!next) return '<p>此物没有可用的装备预览。</p>';
  let rows='';
  if(before&&before.family===next.family) rows=Object.entries(statDefinitions).filter(([k])=>Number.isFinite(next[k])&&Number.isFinite(before[k])).map(([k,meta])=>{
    const delta=Math.round((next[k]-before[k])*10)/10,benefit=delta*meta.good;
    return `<div class="comparison-line"><span>${meta.title}</span><span>${before[k]} → ${next[k]}${meta.unit}</span><b class="${benefit>0?'benefit':benefit<0?'tradeoff':'neutral'}">${delta>0?'+':''}${delta}${meta.unit} · ${benefit>0?'收益':benefit<0?'代价':'不变'}</b></div>`;
  }).join('');
  else rows=`<p>武器类型：${before?.family==='blade'?'刀剑':old?.name||'空槽'} → ${next.family==='bow'?'弓':i.name}。不同武器家族不做综合伤害排名。</p><div class="comparison-line"><span>重量</span><span>${before?.weight||0} → ${next.weight}</span></div>`;
  const family=next.family;
  const impact=family==='bow'?'射击需要身上实有箭矢；刀剑「轻→重 · 破势斩」不再满足武器条件。':family==='blade'?'保留刀剑「轻→重 · 破势斩」的武器条件；仍须真实连招与窗口。':'防护或稳定属性变化；不能据此推断不存在的攻击招式。';
  return `<h3>对比 ${old?.name||'当前空槽'}</h3>${rows}<p class="compatibility">${impact}</p><small>预览只读样例定义，不换装、不转移涂层、不支付费用。</small>`;
}

// Keep typed sample values authoritative for equipment presentation.
for(const i of items) if(equipmentDefinitions[i.definition]) {i.weight=String(equipmentFacts(i).weight);i.stats=equipmentStats(i);}
items.push({id:'travel_blade',definition:'travel_blade',owner:'player',source:'pack',name:'行路轻刃',type:'equipment',icon:'sword',qty:1,slot:'主手',weight:'1.1',value:6,lore:'更轻的行路短刃，节省体力的代价是较低伤害与稳定削减。',stats:[]});
items.find(i=>i.id==='travel_blade').stats=equipmentStats(items.find(i=>i.id==='travel_blade'));
items.push({...items.find(i=>i.id==='cloth'),id:'stash_cloth',owner:'stash',source:'stash',qty:4,equipped:false});

function preparationPage() {
  const rows=preparationRows(),missing=rows.reduce((n,r)=>n+r.missing,0);
  return menuShell('本次准备',`<div class="two-pane"><aside class="list-pane"><div class="section-label">固定目标 ${state.goals.length} / 3</div>${Object.entries(preparationDefinitions).map(([id,d])=>`<button class="list-entry ${state.goals.some(g=>g.id===id)?'active':''}" data-pin="${id}"><b>${d.name}</b><small>${state.goals.some(g=>g.id===id)?'已固定 · 点击移除':'点击固定，不消费'}</small></button>`).join('')}<p class="hint-line">清单是你的准备意图，不新增任务，不锁定物品，不自动补料。</p></aside>
    <div class="work-main"><div class="content-scroll"><div class="top-data"><div><span class="eyebrow">远征 / 由实物更新</span><h2 class="page-title">准备好下一程</h2></div><span data-prep-summary>缺项 ${missing}</span></div>
    <div class="goal-list">${state.goals.map(g=>{const d=preparationDefinitions[g.id];return `<div class="goal-row"><div><b>${d.name}</b><small>${d.kind==='craft'?`已实际加工 ${Math.min(g.done,g.amount)} / ${g.amount}`:d.desc}</small></div><label>份数 <input type="number" min="1" max="9" value="${g.amount}" data-goal-amount="${g.id}" aria-label="${d.name}份数"></label><button data-pin="${g.id}" aria-label="移除${d.name}">×</button></div>`;}).join('')||'<p class="prose">尚未固定目标。选一项开始，不会创建或消费物品。</p>'}</div>
    <div class="preparation-table">${rows.map(r=>`<section class="preparation-row" data-prep-material="${r.id}"><div><b>${template(r.id).name}</b><small>${r.goals.length>1?`共用于${r.goals.length}个目标：`:''}${r.goals.join(' / ')}</small></div><div class="need-values"><span>共需 <b>${r.need}</b></span><span>身上 <b data-prep-have>${r.have}</b></span><span class="${r.missing?'tradeoff':'benefit'}">缺少 <b data-prep-missing>${r.missing}</b></span></div><p class="hint-line">${r.elsewhere?`镇中寄存箱另有${r.elsewhere}份，未计入身上可用。`:'尚无其他已知来源记录。'}${r.elsewhere?'<button data-action="known-supply">查看已知地点</button>':''}</p></section>`).join('')}</div></div>
    <div class="work-actions"><button data-view="inventory">回到行囊</button><button data-view="craft">查看已知配方</button><button data-explain="load">来源与容量规则</button></div></div></div>`,`${key('Esc')} 返回世界　·　准备目标不改变库存或快捷绑定`);
}
function batchPanel() {
  const selected=state.batchSelected.map(getItem).filter(Boolean),protectedCount=selected.filter(i=>!safeForBatch(i)).length;
  return `<div class="inventory-batch"><div><b data-batch-count>已选 ${selected.length} 项实物</b><small>保护项 ${protectedCount} · 金额以商人实际报价为准</small></div><div class="actions-row"><button data-action="batch-safe">选择当前筛选中的可售项</button><button data-action="batch-clear">清空选择</button><button class="primary" data-action="batch-wares">标为待售</button><button data-view="trade">到买卖检查</button></div></div>`;
}
function loadWares() {
  const wares=items.filter(i=>owned(i)&&state.organization[i.id]?.ware),safe=wares.filter(safeForBatch);
  state.tradeMode='sell';state.basket={};state.basketConsent={};
  for(const i of safe) {state.basket[i.id]=i.qty;state.basketConsent[i.id]='';}
  render();toast(`载入${safe.length}项待售，跳过${wares.length-safe.length}项保护实物；尚未结算`);
}
function refreshBatchSelection(id) {
  state.batchSelected=state.batchSelected.includes(id)?state.batchSelected.filter(x=>x!==id):[...state.batchSelected,id];
  selectInventoryItem(id);
  const panel=$('.inventory-batch');if(panel) panel.outerHTML=batchPanel();
}
function handleDecisionAction(a) {
  const i=getItem(state.selected);
  switch(a) {
    case 'favorite':markItem(state.selected,'favorite');render();return true;
    case 'ware':markItem(state.selected,'ware');render();return true;
    case 'open-prepare':openView('prepare');return true;
    case 'batch-mode':state.batchMode=!state.batchMode;state.batchSelected=[];state.binding=false;render();return true;
    case 'batch-safe':state.batchSelected=visibleItems().filter(safeForBatch).map(i=>i.id);render();return true;
    case 'batch-clear':state.batchSelected=[];render();return true;
    case 'batch-wares':{
      if(!state.batchSelected.length) {toast('先选择要整理的实物','error');return true;}
      if(state.batchSelected.some(id=>!safeForBatch(getItem(id)))) {toast('包含收藏、已穿戴、绑定、准备所需或失效来源；请先取消这些项','error');return true;}
      for(const id of state.batchSelected) {const meta=state.organization[id] ||= {};meta.ware=true;}
      render();toast('已标为待售，尚未出售或收款');return true;
    }
    case 'load-wares':loadWares();return true;
    case 'known-supply':state.mapPin='town';openView('map');return true;
    case 'notification-history':state.drawer='notifications';state.forms=false;state.slotPanel=false;renderSelector();return true;
    case 'sound-toggle':state.uiSound=!state.uiSound;render();if(state.uiSound) playCue('info',true);return true;
    case 'sound-accept':playCue('accepted',true);return true;
    case 'sound-reject':playCue('rejected',true);return true;
  }
  return false;
}
function decisionDrawer() {
  if(state.drawer==='help') {
    const g=ruleGlossary[state.helpTopic]||ruleGlossary.source;
    return `<section class="world-drawer help-drawer" aria-label="规则解释"><div class="drawer-top"><span class="eyebrow">规则 / 只读解释</span><button data-action="close-drawer" aria-label="关闭解释">×</button></div><h2>${g.title}</h2><p class="prose">${g.body}</p><p class="hint-line">${g.note}</p><button data-action="close-drawer">回到原来的查看位置</button></section>`;
  }
  if(state.drawer==='notifications') return `<section class="world-drawer" aria-label="近期消息"><div class="drawer-top"><span class="eyebrow">近期反馈 / 只读记录</span><button data-action="close-drawer" aria-label="关闭消息记录">×</button></div><h2>最近发生了什么</h2><div class="notification-log">${state.notifications.slice().reverse().map(n=>`<div class="log-line ${n.priority}"><small>${n.priority==='error'?'拒绝/错误':'操作反馈'}</small><p>${esc(n.message)}${n.count>1?' ×'+n.count:''}</p></div>`).join('')||'<p>尚无反馈。</p>'}</div><p class="hint-line">最多保留20条。查看与关闭不会重新执行操作或领取物品。</p></section>`;
  return null;
}
function statusDisplay() {
  if(!state.statusFixture) return '';
  return `<div class="status-strip" aria-label="复合状态静态样例"><span class="eyebrow">复合状态 · 静态样例</span><div class="status-entry buildup"><span class="status-shape">◌</span><span>人物 / 毒性积累</span><b>65%</b><i style="--progress:65%"></i></div><div class="status-entry active"><span class="status-shape">◆</span><span>人物 / 中毒已生效</span><b>18秒</b></div><div class="status-entry field"><span class="status-shape">▱</span><span>地面 / ${state.field?'火石阵':'无可用法阵'}</span><b>${state.field?'余能80':''}</b></div><button data-explain="statuses">状态归属说明</button></div>`;
}

// Messages have explicit severity; the UI never infers domain success from wording.
const notificationPriority={info:0,error:2};
function publishNotification(message,priority='info',kind='notice') {
  playCue(priority==='error'?'rejected':kind==='accepted'?'accepted':'info');
  const previous=state.notifications.at(-1);
  if(previous?.message===message&&previous.priority===priority) previous.count++;
  else {state.notifications.push({id:++state.noteSerial,message,priority,kind,count:1});state.notifications=state.notifications.slice(-20);}
  const notice={message,priority,kind,count:1};
  if(state.activeToast?.message===message) {state.activeToast.count++;paintNotification();return;}
  if(!state.activeToast||((notificationPriority[priority]||0)>(notificationPriority[state.activeToast.priority]||0)||priority==='error'&&state.activeToast.priority==='error')) {
    clearTimeout(state.toastTimer);state.activeToast=notice;paintNotification();return;
  }
  const queued=state.pendingToasts.find(n=>n.message===message&&n.priority===priority);
  if(queued) queued.count++;
  else state.pendingToasts.push(notice);
  state.pendingToasts=state.pendingToasts.slice(-6);
}
function paintNotification() {
  clearTimeout(state.toastTimer);
  const notice=state.activeToast,host=$('#toast');
  if(!notice) {host.classList.remove('show');return;}
  host.textContent=notice.message+(notice.count>1?' ×'+notice.count:'');
  host.dataset.priority=notice.priority;host.setAttribute('role',notice.priority==='error'?'alert':'status');host.classList.add('show');
  state.toastTimer=setTimeout(()=>{
    state.pendingToasts.sort((a,b)=>(notificationPriority[b.priority]||0)-(notificationPriority[a.priority]||0));
    state.activeToast=state.pendingToasts.shift()||null;paintNotification();
  },2200);
}
let cueAudio=null;
function playCue(kind,preview=false) {
  if(!state.uiSound) {if(preview&&$('#sound-status')) $('#sound-status').textContent='先开启提示音再试听';return;}
  try {
    cueAudio ||= new AudioContext();cueAudio.resume();
    const oscillator=cueAudio.createOscillator(),gain=cueAudio.createGain(),time=cueAudio.currentTime;
    oscillator.type='sine';oscillator.frequency.setValueAtTime(kind==='rejected'?190:kind==='accepted'?660:430,time);
    oscillator.frequency.exponentialRampToValueAtTime(kind==='rejected'?130:kind==='accepted'?880:500,time+.09);
    gain.gain.setValueAtTime(0,time);gain.gain.linearRampToValueAtTime(Math.max(.0001,state.uiVolume),time+.01);gain.gain.exponentialRampToValueAtTime(.001,time+.12);
    oscillator.connect(gain);gain.connect(cueAudio.destination);oscillator.start(time);oscillator.stop(time+.13);
    oscillator.onended=()=>{oscillator.disconnect();gain.disconnect();};
    if(preview&&$('#sound-status')) $('#sound-status').textContent=`最近试听：${kind==='rejected'?'拒绝':kind==='accepted'?'接受':'提示'} · 原型合成音`;
  } catch {if($('#sound-status')) $('#sound-status').textContent='当前浏览器音频不可用，文字反馈仍保留';}
}
function addStressFixture() {
  if(state.stress) {location.reload();return;}
  state.stress=true;state.capacity=500;state.slotCapacity=120;
  const pool=['sabre','bow','spare_coat','herb','resin','spray_a'];
  const current=items.filter(i=>owned(i)&&i.id!=='coin').length;
  for(let n=current;n<100;n++) {
    const base=template(pool[n%pool.length]);
    const item={...base,id:`stress_${n}`,owner:'player',source:'pack',equipped:false,qty:1,upgrade:Math.floor(n/pool.length)%3,name:base.name+' · 样例'+String(n).padStart(2,'0')+'（回收实物，强化与余量分别保留）',acquiredOrder:++state.acquisition};
    if(item.doses!==undefined) item.doses=1+Math.floor(n/pool.length)%3;
    item.stats=item.type==='equipment'?equipmentStats(item):base.stats.map(r=>[...r]);items.push(item);
  }
  $('#stress-demo').textContent='重置100项样例';render();toast('已切入100项布局夹具，样例容量500/120格；不代表正式背包');
}

const mapPlaces = {
  town:{title:'河谷镇',kind:'亲历地点',source:'本人亲历 · 返镇路线',detail:'已知服务与寄存地点。远处寄存物不能当作身上可用。'},
  camp:{title:'旧猎营',kind:'亲历地点',source:'本人亲历 · 营地记录',detail:'已知的准备与撤回节点。查看记录不等于知道未知地点的全部内容。'},
  archive:{title:'林下档案窖',kind:'已确认入口',source:'旧猎营记录与实际发现入口',detail:'可从原路撤回。入口已知不表示内部机关答案已知。'},
  outpost:{title:'旧驿站',kind:'亲历地点',source:'本人亲历 · 已知道路',detail:'查看已知路线与当地记录。'},
  rumor:{title:'旧工区旧门',kind:'听闻线索 · 范围示意',source:'旧猎营记录中的未证实线索（样例）',detail:'只知道大致方位，没有确认入口坐标；不显示解谜答案或未发现的资源点。'}
};
function mapPage() {
  const place=mapPlaces[state.mapPin]||mapPlaces.archive;
  const diagram=`<svg class="map-art" viewBox="${state.mapX} ${state.mapY} ${1000/state.mapZoom} ${600/state.mapZoom}" preserveAspectRatio="xMidYMid slice"><defs><pattern id="fog-lines" width="11" height="11" patternUnits="userSpaceOnUse"><path d="M0 11L11 0" stroke="#72876a" stroke-width=".6" opacity=".17"/></pattern></defs>${Array.from({length:15},(_,i)=>`<path class="contour" d="M${30+i*24} ${590-i*14}Q${160+i*10} ${60+i*15} ${410+i*18} ${40+i*5}T${940-i*6} ${520-i*12}"/>`).join('')}<path class="river" d="M750 -20Q650 90 690 180T610 310 670 420 530 650"/><path class="road" d="M200 460Q270 390 280 300T420 170L540 130M280 300Q430 310 540 340L690 420M200 460L520 500"/><path d="M470 0H1000V250Q800 230 740 300L660 270 600 120 470 90Z" class="fog"/><path d="M470 0H1000V250Q800 230 740 300L660 270 600 120 470 90Z" fill="url(#fog-lines)"/><circle class="node" cx="200" cy="460" r="9" data-map="town"/><text x="220" y="465">河谷镇</text><circle class="node" cx="280" cy="300" r="7" data-map="camp"/><text x="300" y="305">旧猎营</text><circle class="node" cx="420" cy="170" r="8" data-map="archive"/><text x="438" y="176">林下档案窖</text><circle cx="245" cy="380" r="5" fill="#d5c68f"/><path d="M245 367l-7 11h14Z" stroke="#d5c68f" stroke-width="1"/><text x="264" y="386">你</text><circle class="node" cx="540" cy="340" r="7" data-map="outpost"/><text x="556" y="345">旧驿站</text><text x="760" y="155" opacity=".4">未探索</text><path d="M420 153l-7-10 7-10 7 10Z" fill="#c7af77" stroke="none"/>${state.mapFilter==='all'?'<ellipse class="rumor-area" cx="800" cy="370" rx="100" ry="85" data-map="rumor"/><text x="735" y="375">听闻的大致范围</text>':''}</svg>`;
  return menuShell('行路图',`<div class="map-layout">${diagram}<div class="map-controls"><button data-map-filter="visited" class="${state.mapFilter!=='all'?'active':''}">亲历地点</button><button data-map-filter="all" class="${state.mapFilter==='all'?'active':''}">全部已知</button>${state.mapFilter==='all'?'<button data-map="rumor">听闻线索</button>':''}</div><div class="map-legend">◇ 追踪目标　△ 当前人物<br>○ 亲历地点　▱ 听闻范围<br>滚轮缩放 · 中/右键拖动</div><div class="map-card"><span class="eyebrow">${place.kind}</span><h3>${place.title}</h3><p>${place.detail}</p><small>来源：${place.source}</small>${state.mapPin==='rumor'&&state.mapFilter!=='all'?'<p class="hint-line">范围图层已隐藏；当前线索身份保留。</p>':''}<div class="actions-row"><button data-map-source="${state.mapPin}">查看线索记录</button><button data-action="waypoint" ${state.mapPin==='rumor'?'disabled':''}>${state.mapPin==='rumor'?'未确认精确入口':'个人路标'}</button></div></div></div>`,`${key('M')} 返回　${key('鼠标滚轮')} 缩放　·　仅显示已知信息`);
}
