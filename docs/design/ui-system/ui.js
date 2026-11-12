/* Interactive design model only. Never connects to Godot or production saves. */
const state = {
  view: 'hud', lastView: 'inventory', inventoryEntry: 'I', filter: 'all', container: 'all', query: '',
  slotFilter: '', selected: 'sabre', display: 'list', skill: 'inscribe',
  binding: false, selectedSlot: 'R', awake: false, field: true,
  forms: false, formSnapshot: [], formsBySlot: {}, slotPanel: false,
  hp: 84, stamina: 76, mana: 43, points: 1, perk: false, perkPreview: false,
  uiSound:false,uiVolume:.08,hudMode:'standard',statusFixture:false,helpTopic:'source',pageContexts:{},
  tracked: true, minute: 8 * 60 + 42, threat: false, combat: false, art: false,
  mapPin: 'archive', mapZoom: 1, mapX: 0, mapY: 0,
  craft: 'rag', dialogue: 'intro', compare: false, context: null, focusReturn: null,
  tradeMode: 'sell', tradeSelected: 'spare_coat', basket: {}, merchantCoins: 12,
  capacity: 40, fullPackDemo: false, lootSelected: 'loot_spray', lootAmount: 1,
  serial: 0, toastTimer: null, artTimer: null,
  goals: [{id:'repair',amount:1,done:0}], organization: {}, inventorySort:'type', listMode:'all',
  batchMode:false, batchSelected:[], basketConsent:{}, slotCapacity:30, stress:false,
  notifications:[], pendingToasts:[], activeToast:null, noteSerial:0, acquisition:items.length
};
const bindings = {
  Q: {kind: 'ability', id: 'inscribe'}, E: {kind: 'item', id: 'spray_a'},
  R: {kind: 'ability', id: 'ignite'}, 1: {kind: 'item', id: 'oil'},
  2: {kind: 'item', id: 'rag'}, 7: {kind: 'item', id: 'ration'},
  8: {kind: 'item', id: 'water'}, 9: {kind: 'item', id: 'tea'},
  0: {kind: 'item', id: 'broth'}
};
const sections = [['inventory','行囊','I'],['character','角色','P'],['skills','技艺','K'],['journal','手札','J'],['map','行路图','M']];
const typeNames = {equipment:'装备',consumable:'消耗品',material:'材料',quest:'任务'};
const sourceNames = {gear:'穿戴',pocket:'随身口袋',pack:'背包',ground:'脚边',merchant:'商人',stash:'镇中寄存箱'};
const getItem = id => items.find(i => i.id === id);
const owned = i => !!i && i.owner === 'player' && i.qty > 0;
const equipped = slot => items.find(i => owned(i) && i.equipped && i.slot === slot);
const totalWeight = () => items.filter(owned).reduce((v,i) => v + Number(i.weight) * i.qty, 0);
const weightText = () => totalWeight().toFixed(1);
const stackCount = () => items.filter(i => owned(i) && i.source === 'pack').length;
const coins = () => getItem('coin').qty;
const maxStamina = () => state.perk ? 115 : 100;
const clock = () => `第${2 + Math.floor(state.minute / 1440)}日 ${String(Math.floor(state.minute / 60) % 24).padStart(2,'0')}:${String(state.minute % 60).padStart(2,'0')}`;
const esc = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const quantity = i => i.doses !== undefined ? `${i.doses}/3剂` : `×${i.qty}`;
const bindingInfo = k => bindings[k]?.kind === 'ability' ? abilities[bindings[k].id] : getItem(bindings[k]?.id);
const isAbility = k => bindings[k]?.kind === 'ability';
const template = id => items.find(i => i.id === id) || items.find(i => i.definition === id);
const cloneItem = (id, overrides) => ({...template(id), stats: template(id).stats.map(r=>[...r]), ...overrides});
items.push(
  cloneItem('water',{id:'vendor_water',owner:'merchant',source:'merchant',qty:3,equipped:false}),
  cloneItem('cloth',{id:'vendor_cloth',owner:'merchant',source:'merchant',qty:4,equipped:false}),
  cloneItem('spray_a',{id:'loot_spray',name:'树脂喷剂 · III',owner:'ground',source:'ground',qty:1,doses:1,equipped:false}),
  cloneItem('herb',{id:'loot_herb',owner:'ground',source:'ground',qty:3,equipped:false})
);

function toast(message,priority='info',kind='notice') { publishNotification(message,priority,kind); }

// Filled silhouettes distinguish game objects from line navigation icons.
function itemArt(i) {
  const color = ({sword:'#c6c6ac',bow:'#b5a16d',shield:'#9d9471',coat:'#99a58e',flask:'#b1bd8a',bottle:'#b59b63',grain:'#c8b080',drop:'#8baeb3',leaf:'#9db184',rock:'#a7ac9a',cloth:'#c8b9a0',cup:'#c4b08b',book:'#bba987',coin:'#cfb779'})[i.icon] || '#b9b99f';
  return `<span class="object-art object-${i.icon}" style="--object-color:${color}">${icon(i.icon)}${i.doses!==undefined?`<span class="bottle-mark">${i.name.split('·')[1]?.trim()||'I'}</span>`:''}</span>`;
}

function visibleItems() {
  const list=items.filter(i => owned(i) && i.id !== 'coin'
    && (state.filter === 'all' || i.type === state.filter)
    && (state.container === 'all' || i.source === state.container)
    && (!state.slotFilter || i.slot === state.slotFilter)
    && i.name.includes(state.query)
    && (state.listMode==='all'||state.organization[i.id]?.[state.listMode]));
  const order={equipment:0,consumable:1,material:2,quest:3};
  return list.sort((a,b)=>state.inventorySort==='recent'?(b.acquiredOrder||0)-(a.acquiredOrder||0):state.inventorySort==='weight'?Number(b.weight)*b.qty-Number(a.weight)*a.qty:state.inventorySort==='value'?b.value*b.qty-a.value*a.qty:state.inventorySort==='name'?a.name.localeCompare(b.name):order[a.type]-order[b.type]||(a.acquiredOrder||0)-(b.acquiredOrder||0));
}

function statusForSlot(k) {
  const b = bindings[k], v = bindingInfo(k);
  if (!v) return '空槽';
  if (b.kind === 'item') {
    if (!owned(v)) return v.owner === 'merchant' ? '已售出' : '来源不在身上';
    if (v.doses === 0) return '这只瓶已空';
    return quantity(v);
  }
  return v.magic && !state.awake ? '尚未觉醒' : '';
}

function formCatalog(k) {
  const b = bindings[k], v = bindingInfo(k);
  if (!v) return [];
  if (b.kind === 'item' && v.doses !== undefined) return [
    {id:'base',name:'普通喷洒',cost:'1剂 · 0 MP',source:v.name,icon:'flask',reason:!owned(v)?'指定瓶不在身上':v.doses<1?'指定瓶已空':''}
  ];
  if (b.kind !== 'ability') return [];
  const locked = v.magic && !state.awake ? '尚未觉醒' : '';
  if (b.id === 'inscribe') return [
    {id:'base',name:'凝能阵',cost:'8 MP',source:'无材料',icon:'spark',reason:locked || (state.mana<8?'法力不足':'')},
    {id:'fire',name:'火石阵',cost:'8 MP + 火石1',source:'背包中的火石',icon:'flame',reason:locked || (state.mana<8?'法力不足':!items.some(i=>owned(i)&&i.definition==='stone')?'缺少火石':'')}
  ];
  if (b.id === 'ignite') return [
    {id:'base',name:'基础火花',cost:'4 MP',source:'自身法力',icon:'flame',reason:locked || (state.mana<4?'法力不足':'')},
    {id:'fire',name:'火阵 → 火球',cost:'12 MP · 消耗阵能',source:'脚下火石阵',icon:'spark',reason:locked || (!state.field?'已离开火石阵':state.mana<12?'法力不足':'')}
  ];
  if (b.id === 'spray') return [{id:'source',name:'普通喷洒',cost:'1剂 · 0 MP',source:'尚未指定瓶',icon:'flask',reason:'请在行囊明确绑定具体喷剂'}];
  return [];
}

function currentForm(k) {
  const list = formCatalog(k);
  return list.find(f => f.id === (state.formsBySlot[k] || 'base')) || null;
}

function slotSummary(k) {
  const v = bindingInfo(k), f = currentForm(k);
  if (!v) return '空槽 · 查看后可编组';
  if (f) return `${f.name} · ${f.reason || f.cost} · 固定`;
  return `${v.name} · ${statusForSlot(k)}`;
}

function quickbar(mode = 'hud') {
  return `<div class="${mode==='hud'?'quickbar':'binding-row'}" aria-label="13个独立快捷槽">${keys.map(k => {
    const v = bindingInfo(k), reason = statusForSlot(k);
    const unavailable = !!v && (isAbility(k) ? v.magic && !state.awake : !owned(v) || v.doses === 0);
    return `<button class="quick-slot ${['Q','E','R'].includes(k)?'featured':''} ${!v?'empty':''} ${unavailable?'unavailable':''} ${state.selectedSlot===k?'selected':''}"
      data-${mode==='hud'?'slot':'bind-slot'}="${k}" title="${k} · ${v?.name||'空槽'} · ${reason}" aria-label="${k}槽 ${v?.name||'空槽'}" aria-pressed="${state.selectedSlot===k}">
      <small>${k}</small>${v?icon(v.icon):'<span class="slot-empty">—</span>'}
      <span class="count">${v?(unavailable?'!':bindings[k].kind==='item'?(v.doses!==undefined?`${v.doses}剂`:v.qty):''):''}</span>
    </button>`;
  }).join('')}</div>`;
}

function meter(name,value,max,color) {
  return `<div class="meter" style="--value:${value/max*100}%;--color:${color}">${icon(name)}<div class="track"><i></i></div><span>${value} / ${max}</span></div>`;
}

function renderHUD() {
  const hudMode=state.threat||state.combat?'combat':state.hudMode;
  $('#hud').innerHTML = `<div class="hud mode-${hudMode} ${state.hp<=30||state.stamina<=25?'critical':''}">
    <div class="compass">西北　　北　　东北<div class="ticks">│　　　·　　　◇　　　·　　　│</div><div class="location">灰河谷 · 林地</div></div>
    ${state.tracked?'<button class="quest-brief" data-view="journal"><span class="eyebrow">首次出征</span><b>调查林下档案窖</b><span>恢复东侧压印台 · 2 / 3</span></button>':''}
    ${state.combat?'<div class="combat-target"><b>守林兵</b><div class="enemy-track"><i></i></div><small>持盾 · 正面格挡</small></div>':''}
    <div class="vitals"><div class="actor-name">行者 / 等级3</div>
      ${meter('heart',state.hp,100,'var(--health)')}${meter('stamina',state.stamina,maxStamina(),'var(--stamina)')}${state.awake?meter('drop',state.mana,60,'var(--mana)'):''}
      <div class="statuses"><button class="status-icon" data-action="buff-detail" title="饱食：持续改善恢复 · 样例82秒" aria-label="查看饱食状态">${icon('grain')}</button>
      ${equipped('主手')?.id==='sabre'?'<span class="weapon-state">'+icon('sword')+'火焰涂附 · 样例52秒</span>':''}</div>
    ${statusDisplay()}</div>
    <button class="current-source" data-action="source-settings">${key(state.selectedSlot)} <b>${bindingInfo(state.selectedSlot)?.name||'空槽'}</b><span>${slotSummary(state.selectedSlot)}</span></button>
    ${quickbar()}<div class="quick-hint">${key('G')} 选形式　${key('K')} 完整编组　·　选择不施放</div>
    <div class="hud-utility"><button data-view="inventory" aria-label="打开行囊">${icon('bag')}${key('I')}</button><button data-view="map" aria-label="打开地图">${icon('map')}${key('M')}</button></div>
    ${!state.combat?'<div class="interaction"><button data-action="read">'+key('F')+' 旧猎营记录</button></div>':''}
    ${state.art&&equipmentFacts(equipped('主手'))?.family==='blade'?'<div class="art-window"><span class="eyebrow">轻击 → 重击 · 演示窗口</span><div><b>破势斩</b>'+key('Ctrl + 左键')+'</div><div class="window-line"></div><small>按住重式 · Ctrl切换第二招</small></div>':''}
  </div>`;
}

function menuShell(title,body,footer='') {
  return `<div class="menu-shade"></div><section class="menu" aria-label="${title}">
    <header class="menu-top"><h1>${title}</h1><nav class="menu-tabs" aria-label="整备页">${sections.map(([id,label,k])=>`<button class="${state.view===id?'active':''}" data-view="${id}">${label}<small>${k}</small></button>`).join('')}</nav><button class="close" data-action="close">${key('Esc')} 返回世界</button></header>
    <div class="menu-clock"><span>◇ 世界继续运行</span><span>河谷时刻 <span data-clock>${clock()}</span></span></div>
    <div class="menu-body">${body}</div><footer class="menu-bottom"><div>${footer}</div><div class="mini-vitals"><span>生命 ${state.hp}/100</span><span>体力 ${state.stamina}/${maxStamina()}</span>${state.awake?`<span>法力 ${state.mana}/60</span>`:''}</div></footer></section>`;
}

function paperdoll() {
  return `<div class="section-label">穿戴示意 / 读取样例实物</div><div class="equipment-preview"><div class="paperdoll-sprite" role="img" aria-label="${equipped('躯干')?.name||'未穿护衣'}，${equipped('主手')?.name||'徒手'}"><span class="base-body"></span><svg viewBox="0 0 32 32" aria-hidden="true">${equipped('躯干')?'<path d="M12 16h8v6h-8z" fill="'+(equipped('躯干').id==='spare_coat'?'#7e7a5e':'#657e70')+'" stroke="none"/>':''}${equipped('主手')?'<g transform="translate(20 14) scale(.4)" fill="#b7b59a" stroke="#ddd4b2" stroke-width="1.5"><path d="'+paths[equipped('主手').icon]+'"/></g>':''}${equipped('副手')?'<g transform="translate(6 15) scale(.35)" fill="#827b52" stroke="#c5b686" stroke-width="1.5"><path d="'+paths.shield+'"/></g>':''}</svg></div><strong>${equipped('主手')?.name||'徒手'}</strong><small>${equipped('躯干')?.name||'未穿护衣'}</small></div>
    <div class="gear-list">${[['头部','helmet'],['躯干','coat'],['主手','sword'],['副手','shield'],['足部','boots'],['饰物','ring']].map(([slot,ic])=>`<button class="gear-slot ${equipped(slot)?'filled':''}" data-action="gear" data-value="${slot}" title="${slot} · ${equipped(slot)?.name||'空槽'}">${icon(equipped(slot)?.icon||ic)}<span><small>${slot}</small><b>${equipped(slot)?.name||'空槽'}</b></span></button>`).join('')}</div>
    <div class="gear-stat"><span>防护</span><b>${equipped('躯干')?.stats[0][1]||'0%'}</b></div><div class="gear-stat"><span>负重</span><b>${weightText()} / ${state.capacity.toFixed(1)}</b></div>`;
}

function itemTiles(list) {
  if (!list.length) return `<div class="empty-state"><span>◇</span><h2>${state.slotFilter?`没有可穿戴的${state.slotFilter}装备`:'没有符合条件的物品'}</h2><p>清除筛选可查看其他实物，来源不会自动切换。</p><button data-action="clear-filter">清除筛选</button></div>`;
  return list.map(i=>`<button class="item-tile ${state.selected===i.id?'selected':''}" data-item="${i.id}" aria-pressed="${state.batchMode?state.batchSelected.includes(i.id):state.selected===i.id}" aria-label="${i.name}${state.batchMode?' 批量选择':''}" title="${i.name} · ${quantity(i)}">
    ${state.batchMode?'<span class="selection-mark" aria-hidden="true">'+(state.batchSelected.includes(i.id)?'☑':'□')+'</span>':''}${itemArt(i)}<span class="item-label"><b>${i.name}</b><small>${sourceNames[i.source]}${i.equipped?' · 已穿戴':''}${i.doses!==undefined?' · 独立瓶':''}${organizeBadges(i)?' · '+organizeBadges(i):''}</small></span><strong>${quantity(i)}</strong></button>`).join('');
}

function comparison(i) { return comparisonProjection(i); }

function itemDetail(i) {
  if (!i || !owned(i)) return '<div class="empty-state"><h2>选择一件实物</h2><p>这里显示作用、当前余量和可执行操作。</p></div>';
  return `<div class="detail-scroll"><div class="detail-heading">${itemArt(i)}<div><span class="eyebrow">${typeNames[i.type]} / ${sourceNames[i.source]}</span><h2>${i.name}</h2></div></div>
    <div class="item-meta"><span>重量 ${i.weight}</span><span>参考价值 ${i.value}币</span>${i.slot?`<span>${i.slot}</span>`:''}</div>
    ${(i.type==='equipment'?equipmentStats(i):i.stats).map(([k,v])=>`<div class="stat-row"><span>${k}</span><b>${k==='剩余剂量'?i.doses+' / 3':v}</b></div>`).join('')}
    ${i.id==='sabre'?'<div class="effect">火焰涂附 · 样例52秒<small>附在这把短刀。普通命中附加火伤；显式元素武技消耗此涂层。</small></div>':''}
    ${state.compare&&i.slot?`<div class="compare-tip">${comparison(i)}</div>`:''}
    <details class="item-lore"><summary>物品来历与完整说明</summary><p>${i.lore}</p></details>
    <div class="rule-links"><button data-explain="source">来源规则</button>${i.slot?'<button data-explain="stamina">体力与打法</button>':'<button data-action="open-prepare">本次准备</button>'}</div><p class="hint-line">同名物品保留各自身份。选材和快捷绑定不消费实物。</p></div>
    <div class="detail-actions"><div class="actions-row">
      ${i.type==='equipment'?`<button class="primary" data-action="equip">${i.equipped?'卸下':'穿戴'}</button>`:i.type==='consumable'?'<button class="primary" data-action="use">使用</button>':''}
      ${i.type!=='quest'?'<button data-action="bind-item">绑定快捷槽</button><button data-action="context" aria-label="更多物品操作">更多</button>':''}
      ${i.slot?`<button data-action="compare" aria-pressed="${state.compare}">比较</button>`:''}<button data-action="favorite" aria-pressed="${!!state.organization[i.id]?.favorite}">${state.organization[i.id]?.favorite?'★ 已收藏':'☆ 收藏'}</button><button data-action="ware" ${i.type==='quest'?'disabled title="任务记录不列入待售"':''} aria-pressed="${!!state.organization[i.id]?.ware}">${state.organization[i.id]?.ware?'取消待售':'标为待售'}</button>
    </div></div>`;
}

function inventory() {
  const list=visibleItems();
  if (!list.some(i=>i.id===state.selected)) state.selected=list[0]?.id||'';
  return menuShell('行囊',`<div class="inventory-layout"><aside class="gear-pane"><button class="prepare-entry" data-action="open-prepare">本次准备 · ${state.goals.length}项目标</button>${paperdoll()}</aside><section class="bag-pane">
    <div class="bag-top"><span>行者的实物</span><span class="value">${icon('coin')} ${coins()}</span></div>
    <div class="tabs-small">${[['all','全部来源'],['pocket','口袋'],['pack','背包']].map(([id,t])=>`<button data-container="${id}" class="${state.container===id?'active':''}">${t}</button>`).join('')}</div>
    <div class="tabs-small categories">${[['all','全部'],['equipment','装备'],['consumable','补给'],['material','材料'],['quest','任务']].map(([id,t])=>`<button data-filter="${id}" class="${state.filter===id?'active':''}">${t}</button>`).join('')}</div>
    <div class="search-row"><input class="search" id="item-search" placeholder="搜索名称…" aria-label="搜索物品" value="${esc(state.query)}"><button data-action="toggle-display" aria-label="切换列表或网格">${state.display==='list'?'网格':'列表'}</button></div>
    <div class="organize-tools"><select id="list-mode" aria-label="物品标记筛选"><option value="all" ${state.listMode==='all'?'selected':''}>全部标记</option><option value="favorite" ${state.listMode==='favorite'?'selected':''}>收藏</option><option value="ware" ${state.listMode==='ware'?'selected':''}>待售</option></select><select id="inventory-sort" aria-label="物品排序">${[['type','按类别'],['recent','最近获得'],['name','按名称'],['weight','按总重'],['value','参考总值']].map(([v,t])=>`<option value="${v}" ${state.inventorySort===v?'selected':''}>${t}</option>`).join('')}</select><button data-action="batch-mode" aria-pressed="${state.batchMode}">${state.batchMode?'结束批量':'多选'}</button></div>
    ${state.stress?'<small class="fixture-note">100项独立样例 · 容量500/120格，不代表正式背包</small>':''}
    ${state.slotFilter?`<button class="filter-chip" data-action="clear-filter">${state.slotFilter}装备 ×</button>`:''}
    <div class="bag-grid ${state.display}" id="bag-grid">${itemTiles(list)}</div><div class="bag-footer"><span>${weightText()} / ${state.capacity.toFixed(1)} 负重 · ${stackCount()} / ${state.slotCapacity}格</span><button data-action="sort">整理</button></div>
    </section><aside class="detail-pane" id="item-detail">${itemDetail(getItem(state.selected))}</aside></div>
    ${state.batchMode?batchPanel():''}
    ${state.binding?`<div class="inventory-binding"><div><b>绑定：${getItem(state.selected)?.name}</b><button data-action="cancel-binding">取消</button></div>${quickbar('bind')}</div>`:''}`,
    `${key('双击')} 使用/穿戴　${key('右键')} 更多　${key('Shift')} 比较`);
}

function skillPage() {
  const a=abilities[state.skill];
  return menuShell('技艺',`<div class="skill-layout"><aside class="list-pane"><div class="section-label">已掌握的操作</div>${Object.entries(abilities).map(([id,v])=>`<button class="list-entry ${state.skill===id?'active':''}" data-skill="${id}"><span class="eyebrow">${id==='breaker'?'武技 / 连招窗口':v.magic?'主动法术':'实物操作'}</span><b>${v.name}</b><small>${!state.awake&&v.magic?'公式已知 · 尚未觉醒':id==='breaker'?'轻→重 · Ctrl+左键':'已掌握'}</small></button>`).join('')}</aside>
    <div class="skill-main"><div class="content-scroll"><span class="eyebrow">知识与编组</span><h2 class="page-title">${a.name}</h2><p class="prose">${a.desc}</p>
    ${state.skill==='breaker'?`<div class="source-note"><div>轻击 → 重击<small>真实连招形成窗口，每组合最多配置两招</small></div><div>${key('Ctrl + 左键')}<small>短按轻式 / 按住重式</small></div></div><div class="actions-row"><button data-action="technique">破势斩 · 已配置</button><button data-action="technique">另一招</button></div><p class="prose">武技不占快捷槽。Ctrl 切换不刷新窗口；显式消耗附魔仍需 Ctrl+Shift。</p>`:
    `<div class="source-note"><div>当前槽 ${key(state.selectedSlot)}<small>${slotSummary(state.selectedSlot)}</small></div><button data-action="source-settings">查看形式与来源</button></div><p class="prose">选择动作后，点击下方目标槽。Q/E/R 与 1—0 都可放动作或物品，彼此独立。</p>`}
    <p class="hint-line">完整知识可在此阅读；临场 G 只显示当前满足条件的形式。选择不自动准备、不施放。</p></div>
    <div class="skill-bindings"><div class="section-label">${state.skill==='breaker'?'武技不绑定下方槽位':'将所选动作放入独立快捷槽'}</div>${quickbar('bind')}<div class="actions-row"><button data-action="clear-slot">清空 ${state.selectedSlot}</button><button data-view="inventory">从行囊绑定实物</button></div></div></div></div>`,`${key('Tab')} 移动焦点　${key('右键')} 清槽　${key('Esc')} 返回`);
}

function character() {
  return menuShell('角色',`<div class="two-pane"><aside class="list-pane"><span class="section-label">行者 / 等级3</span><div class="list-entry active"><b>属性与成长</b><small>已有点数 ${state.points}</small></div><p class="prose">点节点查看详情，再由你明确学习。知识仍需训练与探索。</p></aside>
    <div class="progression-main"><div class="content-scroll"><div class="top-data"><div><span class="eyebrow">成长 / 共同角色规则</span><h2 class="page-title">呼吸与力量</h2></div><span>${state.points} 个可用Perk点</span></div>
    <div class="stat-columns"><div>${[['力量','12'],['耐力','11'],['敏捷','10'],['智力','10']].map(([k,v])=>`<div class="stat-row"><span>${k}</span><b>${v}</b></div>`).join('')}</div><div>${[['生命上限','100'],['体力上限',maxStamina()],['负重上限','40'],['资格',state.awake?'已觉醒':'尚未觉醒']].map(([k,v])=>`<div class="stat-row"><span>${k}</span><b>${v}</b></div>`).join('')}</div></div>
    <div class="perk-tree"><button class="perk-node learned" data-action="perk-detail">基础战斗<small>已掌握</small></button><button class="perk-node ${state.perk?'learned':''}" data-action="learn-perk">战斗调息<small>${state.perk?'已学会':'体力上限 +15 · 1点'}</small></button><button class="perk-node" data-action="perk-detail">连段节能<small>前置与实践未满足</small></button></div></div>
    <div class="perk-preview" aria-live="polite">${state.perkPreview?`<div><b>战斗调息</b><small>体力上限 ${state.perk?'115':'100 → 115'} · 不自动回满体力</small></div><button class="primary" data-action="confirm-perk" ${state.perk||state.points<1?'disabled':''}>${state.perk?'已学会':'学习 · 1点'}</button>`:'点击节点只预览，不分配点数。'}</div></div></div>`,`${key('鼠标')} 预览节点　${key('Tab')} 移动焦点　${key('Esc')} 返回`);
}

const recipeCosts = id => id==='rag'?{resin:1,charcoal:1,cloth:1}:{ash:2,crystal:1};
const available = definition => items.filter(i=>owned(i)&&i.definition===definition).reduce((n,i)=>n+i.qty,0);
function recipeReady(id) {
  return Object.entries(recipeCosts(id)).every(([def,n])=>available(def)>=n);
}
function crafting() {
  const id=state.craft, output=template(id), costs=recipeCosts(id);
  return menuShell('工作台',`<div class="two-pane"><aside class="list-pane"><span class="section-label">已学配方</span>${['rag','stone'].map(r=>`<button class="list-entry ${id===r?'active':''}" data-craft="${r}"><b>${template(r).name}</b><small>${recipeReady(r)?'原料齐备':'原料不足'} · 实物加工</small></button>`).join('')}<button class="list-entry" data-action="recipe-locked"><b>浓缩毒性喷剂</b><small>尚未学会 · 查看来源</small></button></aside>
    <div class="work-main"><div class="content-scroll"><span class="eyebrow">制造 / 实物加工</span><h2 class="page-title">${output.name}</h2><p class="prose">${id==='rag'?'涂在当前具体武器上，无需觉醒。涂层随这件武器保存。':'阵材只提供释放来源；制造它不授予施法资格。'}</p><div class="craft-grid">${Object.entries(costs).map(([def,n])=>`<div class="ingredient">${itemArt(template(def))}<b>${template(def).name} ×${n}</b><small>可访问 ${available(def)}</small></div>`).join('')}</div><div class="source-note"><div>本次产出 ×1<small>进入背包，容量不足不扣原料</small></div><div>现有 ${available(id)}</div></div><p class="hint-line">使用身上的原料；脚边和商人库存不计入可访问材料。</p></div><div class="work-actions"><button class="primary" data-action="craft">加工1份</button><button data-pin="${id}">${state.goals.some(g=>g.id===id)?'取消固定目标':'固定制作目标'}</button><span>${recipeReady(id)?'原料齐备':'原料不足，当前不能加工'}</span></div></div></div>`,`${key('鼠标')} 选择配方　${key('Esc')} 返回`);
}

function tradePrice(i) { return state.tradeMode==='sell'?Math.max(1,Math.floor(i.value*.6)):Math.max(1,i.value); }
function tradeList() {
  return items.filter(i=>i.qty>0 && i.id!=='coin' && i.type!=='quest'
    && (state.tradeMode==='sell'?i.owner==='player':i.owner==='merchant'));
}
function tradeTotal() {
  return Object.entries(state.basket).reduce((sum,[id,n])=>sum+tradePrice(getItem(id))*n,0);
}
function trade() {
  const list=tradeList();
  if (!list.some(i=>i.id===state.tradeSelected)) state.tradeSelected=list[0]?.id||'';
  const i=getItem(state.tradeSelected), total=tradeTotal();
  return menuShell('买卖',`<div class="trade-layout"><section class="trade-items"><div class="tabs-small"><button data-trade-mode="sell" class="${state.tradeMode==='sell'?'active':''}">卖给商人</button><button data-trade-mode="buy" class="${state.tradeMode==='buy'?'active':''}">从商人购买</button></div><div class="trade-money">你有 ${coins()}币 · 商人有 ${state.merchantCoins}币</div>${state.tradeMode==='sell'?'<button data-action="load-wares">载入可售待售项</button>':''}<div class="trade-list">${list.map(it=>`<button class="trade-item ${state.tradeSelected===it.id?'selected':''}" data-trade-item="${it.id}">${itemArt(it)}<span><b>${it.name}</b><small>${it.equipped?'已穿戴 · 先卸下':quantity(it)}${organizeBadges(it)?' · '+organizeBadges(it):''}</small></span><strong>${tradePrice(it)}币</strong></button>`).join('')||'<p class="empty-state">没有可交易的物品</p>'}</div></section>
    <aside class="trade-inspect">${i?`<span class="eyebrow">报价样例 / ${state.tradeMode==='sell'?'出售':'购买'}</span><h2>${i.name}</h2><div class="stat-row"><span>单件价格</span><b>${tradePrice(i)}币</b></div><div class="stat-row"><span>本件状态</span><b>${quantity(i)}</b></div><p class="prose">${i.lore}</p>${Object.entries(bindings).some(([,b])=>b.id===i.id)?'<p class="effect">这是已绑定来源。出售后槽位保留身份并失效，不自动换物。</p>':''}${protectedReasons(i).length?`<p class="protected-note">保护标记：${protectedReasons(i).join('、')}。手动加入后仍须明确结算。</p>`:''}<button class="primary" data-action="basket-add" ${i.equipped?'disabled':''}>${i.equipped?'先卸下再出售':'加入清单 · 1件'}</button>`:'选择物品查看报价。'}</aside>
    <aside class="trade-basket"><h2>${state.tradeMode==='sell'?'待售':'待购'}清单</h2><div class="basket-lines">${Object.entries(state.basket).map(([id,n])=>`<div class="basket-line"><span>${getItem(id).name} ×${n}</span><button data-remove-basket="${id}" aria-label="移除${getItem(id).name}">×</button></div>`).join('')||'<p class="quiet">单击查看，双击加入清单。浏览不付款。</p>'}</div><div class="basket-total"><span>${state.tradeMode==='sell'?'可得':'需付'}</span><b>${total}币</b></div><button class="primary" data-action="trade-confirm" ${total?'':'disabled'}>确认${state.tradeMode==='sell'?'出售':'购买'}</button><button data-action="basket-clear">清空清单</button><p class="hint-line">确认时重验实物、资金和容量。原型报价不代表正式游戏平衡。</p></aside></div>`,`${key('双击')} 加入清单　·　单击查看不付款`);
}

function lootDrawer() {
  const list=items.filter(i=>i.owner==='ground'&&i.qty>0);
  if (!list.some(i=>i.id===state.lootSelected)) state.lootSelected=list[0]?.id||'';
  const i=getItem(state.lootSelected);
  return `<section class="world-drawer" aria-label="搜取实物"><div class="drawer-top"><span class="eyebrow">现场 / 脚边实物</span><button data-action="close-drawer" aria-label="关闭搜取">×</button></div><h2>旧猎营遗留物</h2><div class="capacity-line">负重 ${weightText()} / ${state.capacity.toFixed(1)}<button data-action="full-pack-demo">${state.fullPackDemo?'恢复容量':'演示满包'}</button></div>
    <div class="loot-list">${list.map(it=>`<button data-loot-item="${it.id}" class="loot-item ${it.id===state.lootSelected?'selected':''}">${itemArt(it)}<span>${it.name}<small>${quantity(it)}</small></span></button>`).join('')||'<p>这里已没有实物，不会补货。</p>'}</div>
    ${i?`<div class="loot-detail"><b>${i.name}</b><p>单件重量 ${i.weight} · ${quantity(i)}</p><label>取走数量 <input id="loot-amount" type="number" min="1" max="${i.qty}" value="${Math.min(state.lootAmount,i.qty)}"></label><button class="primary" data-action="take-loot">取走选定数量</button></div>`:''}<p class="hint-line">容量不足留在原处。专业部位需要另验知识与工具；这里仅展示普通随身物品。</p><button data-view="inventory">查看行囊</button></section>`;
}

function renderSelector() {
  const host=$('#selector');
  const extra=decisionDrawer();
  if(extra!==null) {host.innerHTML=extra;return;}
  if (state.forms) {
    const current=currentForm(state.selectedSlot), catalog=formCatalog(state.selectedSlot);
    const shown=state.formSnapshot.map(id=>catalog.find(f=>f.id===id)).filter(Boolean);
    host.innerHTML=`<section class="form-selector" aria-label="选择当前可用形式"><div class="drawer-top"><span class="eyebrow">${state.selectedSlot} / ${bindingInfo(state.selectedSlot)?.name||'空槽'}</span><button data-action="cancel-forms" aria-label="关闭形式选择">×</button></div><h3>选择形式 · 不施放</h3>
      <p class="current-form-label">当前：${current?.name||'无选材步骤'}${current?.reason?' · '+current.reason:''}</p>
      <div class="form-options" role="group" aria-label="可执行形式">${shown.map(f=>`<button data-form="${f.id}" class="${current?.id===f.id?'selected':''}" aria-pressed="${current?.id===f.id}" ${f.reason?'disabled':''}>${icon(f.icon)}<b>${f.name}</b><small>${f.reason||f.cost}</small><small>${f.source}</small></button>`).join('')}</div>
      ${!shown.length?`<p class="prose">${current?.reason||'此物品没有可选形式；K 可查完整知识，行囊可明确换源。'}</p>`:''}
      <div class="selector-foot"><span>已选择身份不会被替换</span><span>动作键换槽 · Esc取消</span></div></section>`;
  } else if (state.slotPanel) {
    host.innerHTML=`<section class="world-drawer slot-drawer" aria-label="当前槽详情"><div class="drawer-top"><span class="eyebrow">${state.selectedSlot} / 当前快捷槽</span><button data-action="close-drawer" aria-label="关闭槽详情">×</button></div><h2>${bindingInfo(state.selectedSlot)?.name||'空槽'}</h2><p class="prose">${slotSummary(state.selectedSlot)}</p><p class="hint-line">只查看，不施放、不消费。来源失效后仍保留原身份。</p><button class="primary" data-action="source-settings">选择当前形式</button><button data-view="skills">完整技艺与编组</button></section>`;
  } else if (state.drawer==='loot') host.innerHTML=lootDrawer();
  else if (state.drawer==='read') host.innerHTML=`<section class="world-drawer" aria-label="旧猎营记录"><div class="drawer-top"><span class="eyebrow">现场记录</span><button data-action="close-drawer" aria-label="关闭记录">×</button></div><h2>旧猎营记录</h2><p class="prose">档案窖在林地北侧。先在营地整理食水和武器，再靠近入口；确认守林兵巡路已远离时准备阵材。</p><p class="prose">没有魔力也能前往。火石是阵材，主动铭阵仍需觉醒；凝能阵与火石阵不是同一种来源。</p><button data-view="journal">记入手札 / 查看目标</button><button data-action="loot">查看脚边实物</button></section>`;
  else if (state.drawer==='buff') host.innerHTML=`<section class="world-drawer" aria-label="人物状态"><div class="drawer-top"><span class="eyebrow">人物状态</span><button data-action="close-drawer" aria-label="关闭状态">×</button></div><h2>饱食</h2><p class="prose">来自食物，持续改善恢复。此处剩余82秒为样例，不是武器涂层。</p></section>`;
  else host.innerHTML='';
}

function openForms() {
  state.slotPanel=false;state.drawer=null;
  state.forms=true;
  // Snapshot identities when opened. Invalidated candidates stay in place and cannot confirm.
  state.formSnapshot=formCatalog(state.selectedSlot).filter(f=>!f.reason).map(f=>f.id);
  renderSelector();
}

function showContext(kind,options={}) {
  state.focusReturn=document.activeElement;
  state.context={kind,...options};
  renderContext();
}
function closeContext() {
  state.context=null;
  renderContext();
  if (state.focusReturn?.isConnected) state.focusReturn.focus({preventScroll:true});
  state.focusReturn=null;
}
function renderContext() {
  const c=state.context, host=$('#context');
  const modal=!!c && c.kind!=='menu';
  // inert prevents actual pointer/focus access, not merely ignored click handlers.
  for (const id of ['hud','modal','selector']) $('#'+id).inert=modal;
  $('#demo-nav').inert=modal;$('#actor-mode').inert=modal;
  if (!c) {host.innerHTML='';return;}
  if (c.kind==='menu') {
    const i=getItem(state.selected);
    const actions=[...(i.type==='equipment'?[['使用 / 穿戴','use']]:i.type==='consumable'?[['使用','use']]:[]),['绑定快捷槽','bind-item'],['移到口袋','pocket'],...(i.qty>1?[['拆分数量','split']]:[]),['丢弃物品','drop-dialog']];
    host.innerHTML=`<div class="context-menu" role="menu">${actions.map(([label,a])=>`<button role="menuitem" data-action="${a}">${label}</button>`).join('')}</div>`;
    return;
  }
  const i=getItem(c.item), amount=c.kind==='split'||c.kind==='drop';
  host.innerHTML=`<div class="context-backdrop"></div><section class="confirmation" role="dialog" aria-modal="true" aria-labelledby="confirm-title"><span class="eyebrow">${amount?'实物操作':'旅程'}</span><h2 id="confirm-title">${amount?(c.kind==='split'?'拆分：':'丢弃：')+i.name:'重新开始灰河谷？'}</h2>
    ${amount?`<label>数量 <input id="context-amount" type="number" min="1" max="${i.qty}" value="1"></label><p class="prose">${c.kind==='drop'?'转移到脚边，保留实例余量。绑定来源不会自动替换。':'拆分数量，原物品状态不重置；本样例只允许可堆叠材料。'}</p>`:'<p class="prose">正式版会先归档旧旅程。此原型只会刷新示例，绝不访问正式存档。</p>'}
    <div class="actions-row"><button class="primary" data-action="${amount?'confirm-amount':'reset-demo'}">确认${amount?'操作':'刷新示例'}</button><button data-action="cancel-context">取消</button></div></section>`;
  host.querySelector('input,button')?.focus();
}
function journal(){return menuShell('手札',`<div class="two-pane"><aside class="list-pane"><div class="tabs-small"><button class="active">委托</button><button data-action="journal-info">记录</button><button data-action="journal-info">知识</button></div><button class="list-entry active"><span class="eyebrow">河谷 / 首次出征</span><b>林下档案窖</b><small>${state.tracked?'正在追踪':'未追踪'} · 已有两项线索</small></button><button class="list-entry" data-action="journal-info"><b>行路人的准备</b><small>整备与成长建议 · 非强制教程</small></button><button class="list-entry" data-action="journal-info"><b>晚归者的谷物</b><small>苇娘 · 一次性实物交付</small></button></aside><div class="content-scroll"><span class="eyebrow">艾妲 / 河谷档案</span><h2 class="page-title">首次出征：林下档案窖</h2><p class="prose">旧猎营的记录提到一份封锁名册。把它带回镇里，核对那些仍被执行的旧命令。先整理武器和食水；这趟路不要求你拥有魔力。</p><hr class="rule-divider"><div class="section-label">当前目标</div>${[['✓','阅读旧猎营记录','已记入手札，可随时重读'],['○','恢复东侧压印台','可用布料1手工检修；先确认附近安全'],['✓','取得封锁名册','持有证据，报告时不会当作新命令使用']].map(([m,t,d])=>`<div class="objective-line"><span class="mark">${m}</span><div>${t}<small>${d}</small></div></div>`).join('')}<hr class="rule-divider"><div class="section-label">回镇之后</div><p class="prose">报告原有奖励：1属性点。保留趁手装备，比较多余战利品的出售、拆解和强化；补充实际消耗的食水，再自行选择下一程。觉醒仍是另外的选择。</p><div class="actions-row"><button class="primary" data-action="track">${state.tracked?'取消追踪':'追踪委托'}</button><button data-view="map">查看已知路线</button></div></div></div>`,`${key('J')} 手札 ${key('M')} 行路图 ${key('Esc')} 返回`)}

function dialogue(){const speech=state.dialogue==='course'?'“这门课收8币。学会以后，你仍得自己把轻击和重击接起来。力气花完了，再漂亮的招也救不了你。”':state.dialogue==='favor'?'“把药草留给需要的人，是一种准备；把它留给自己，也有你的道理。报酬从实有的钱袋里出。”':'“先把呼吸放稳。你想学招式，还是谈谈为什么总在出招后挨打？”';return menuShell('交谈',`<div class="dialogue-layout"><aside class="npc-scene"><div class="portrait-mark">${icon('sword')}</div><div><span class="eyebrow">当值 / 信任：熟悉</span><h2>河谷训练师</h2><p>武器战技与行路准备<br>没有替你准备的武器，也没有免费的力量。</p></div></aside><div class="dialogue-content"><span class="eyebrow">灰河谷 / 人物</span><div class="speech">${speech}</div><button class="choice" data-dialogue="course">我想学习破势斩。 <span class="quiet">8河谷币</span></button><button class="choice" data-dialogue="favor">学费不足，镇里有哪些活可以做？</button><button class="choice" data-dialogue="intro">先教我如何判断距离和体力。</button>${state.dialogue==='course'?'<div class="source-note" style="margin-top:22px"><div>知识：破势斩<small>刀剑 · 轻→重后的窗口接招 · 不需要MP</small></div><div>现有18币 / 费用8币</div></div><div class="actions-row"><button class="primary" data-action="course-demo">付费学习</button><button data-view="skills">先查看连招条件</button></div>':''}<button class="choice" data-view="trade">我想买卖物品。</button><button class="choice quiet" data-action="close">先告辞了。</button></div></div>`,`${key('鼠标')} 选择话题 ${key('Esc')} 结束交谈`)}
function settings(){return menuShell('系统',`<div class="two-pane"><aside class="list-pane">${[['继续旅程','close'],['保存旅程','save'],['读取旅程','load'],['重新开始','new'],['退出游戏','exit']].map(([t,a])=>`<button class="list-entry" data-action="${a}"><b>${t}</b><small>${a==='new'?'将单独确认并保留旧旅程归档':a==='save'?'记录当前地点与世界事实':''}</small></button>`).join('')}</aside><div class="content-scroll"><span class="eyebrow">偏好 / 可访问性</span><h2 class="page-title">让信息适合你</h2><div class="settings-row"><span>阅读与菜单文字</span><select id="font-setting"><option value="100">标准</option><option value="112">较大</option><option value="125">大字</option></select></div><div class="settings-row"><span>HUD文字与图标</span><select id="hud-setting"><option value="100">标准</option><option value="112">较大</option><option value="125">大字</option></select></div><div class="settings-row"><span>HUD显示方式</span><select id="hud-mode"><option value="standard">标准</option><option value="explore">探索精简</option><option value="combat">战斗完整</option></select></div><div class="settings-row"><span>界面与底色对比</span><select id="contrast-setting"><option value="normal">标准</option><option value="high">高对比</option></select></div><div class="settings-row"><span>减少动态效果</span><button data-action="motion" id="motion-setting">关闭</button></div><div class="settings-row"><span>提示音</span><button data-action="sound-toggle">${state.uiSound?'开启':'关闭'}</button></div><div class="settings-row"><span>提示音音量</span><input id="ui-volume" aria-label="提示音音量" type="range" min="0" max="20" value="${state.uiVolume*100}"></div><div class="actions-row"><button data-action="sound-accept">试听接受</button><button data-action="sound-reject">试听拒绝</button><button data-action="notification-history">近期消息</button></div><p id="sound-status" class="hint-line">声音默认关闭，重要反馈始终有文字。试听不执行动作。</p><div class="settings-row"><span>状态提示</span><span class="quiet">图形 + 文字 + 色彩</span></div><div class="settings-row"><span>自定义按键</span><button class="primary" data-action="bindings-demo">查看冲突与改键</button></div><p class="prose" style="font-size:12px">偏好只改变呈现与操作绑定，不改变世界模拟。危险或资源拒绝信息不会因减少动态效果而消失。</p></div></div>`,`${key('Esc')} 继续旅程`)}

function captureView() {
  const scrolls=[...document.querySelectorAll('.bag-grid,.detail-scroll,.content-scroll,.trade-list,.list-pane')].map((n,index)=>({index,top:n.scrollTop}));
  const node=document.activeElement;
  let selector='';
  if (node?.id) selector='#'+CSS.escape(node.id);
  else if (node?.dataset) for (const attr of ['item','action','bindSlot','skill','tradeItem']) {
    if (node.dataset[attr]) {selector=`[data-${attr.replace(/[A-Z]/g,c=>'-'+c.toLowerCase())}="${CSS.escape(node.dataset[attr])}"]`;break;}
  }
  return {scrolls,selector};
}
function restoreView(saved) {
  const nodes=document.querySelectorAll('.bag-grid,.detail-scroll,.content-scroll,.trade-list,.list-pane');
  saved.scrolls.forEach(s=>{if(nodes[s.index]) nodes[s.index].scrollTop=s.top;});
  if (saved.selector) [...document.querySelectorAll(saved.selector)].find(n=>n.getClientRects().length&&!n.closest('[inert]'))?.focus({preventScroll:true});
}

function render(preserve=true) {
  const saved=preserve?captureView():null;
  renderHUD();
  const renderers={inventory,skills:skillPage,character,journal,map:mapPage,craft:crafting,dialogue,settings,trade,prepare:preparationPage};
  $('#modal').innerHTML=state.view==='hud'?'':renderers[state.view]();
  $('#hud').style.display=state.view==='hud'?'':'none';
  $('#stage').classList.toggle('threat',state.threat);
  $('#stage').classList.toggle('binding-open',state.view==='inventory'&&state.binding);
  $('#danger').textContent='受到威胁 · [Esc] 取消界面准备并返回世界';
  renderSelector();renderStudio();
  if(state.view==='settings') {
    $('#hud-mode').value=state.hudMode;$('#hud-setting').value=String(Math.round((Number($('#hud').style.getPropertyValue('--hud-scale'))||1)*100));
    $('#font-setting').value=String(Math.round((Number($('#stage').style.getPropertyValue('--type-scale'))||1)*100));
    $('#contrast-setting').value=$('#stage').classList.contains('high-contrast')?'high':'normal';
    $('#motion-setting').textContent=document.body.classList.contains('reduced')?'开启':'关闭';
  }
  if(saved) restoreView(saved);
}

function renderStudio() {
  $('#demo-nav').innerHTML=[['hud','探索'],['combat','战斗'],['inventory','行囊'],['prepare','准备'],['skills','技艺'],['character','成长'],['journal','手札'],['map','地图'],['craft','制造'],['dialogue','交谈'],['trade','买卖'],['loot','搜取'],['settings','系统']].map(([id,t])=>`<button data-demo="${id}" class="${state.view===id||id==='combat'&&state.combat&&state.view==='hud'?'active':''}">${t}</button>`).join('');
}
function openView(v) {
  if(state.view!=='hud') state.pageContexts[state.view]=captureView();
  closeContext();state.forms=false;state.slotPanel=false;state.drawer=null;state.binding=false;
  clearTimeout(state.artTimer);state.art=false;
  if(v==='combat') {
    state.view='hud';state.combat=true;state.art=true;
    state.artTimer=setTimeout(()=>{state.art=false;renderHUD();},1100);
  } else if(v==='loot') {state.view='hud';state.drawer='loot';state.combat=false;}
  else {state.view=v;state.combat=false;if(v!=='hud') state.lastView=v;}
  render(false);
  if(state.view!=='hud') {$('.menu .close')?.focus({preventScroll:true});if(state.pageContexts[state.view]) restoreView(state.pageContexts[state.view]);}
}
function returnToWorld() {
  closeContext();state.forms=false;state.drawer=null;state.slotPanel=false;state.binding=false;
  openView('hud');
}

function selectInventoryItem(id) {
  state.selected=id;
  // Selection must not replace the clicked node: native dblclick and focus remain intact.
  document.querySelectorAll('[data-item]').forEach(n=>{
    n.classList.toggle('selected',n.dataset.item===id);
    n.setAttribute('aria-pressed',String(state.batchMode?state.batchSelected.includes(n.dataset.item):n.dataset.item===id));
    const mark=n.querySelector('.selection-mark');if(mark) mark.textContent=state.batchSelected.includes(n.dataset.item)?'☑':'□';
  });
  $('#item-detail').innerHTML=itemDetail(getItem(id));
}
function refreshInventoryList() {
  const list=visibleItems();
  if(!list.some(i=>i.id===state.selected)) state.selected=list[0]?.id||'';
  $('#bag-grid').innerHTML=itemTiles(list);
  $('#item-detail').innerHTML=itemDetail(getItem(state.selected));
}
function updateHUDOnly() {
  renderHUD();renderSelector();
}

function useItem() {
  const i=getItem(state.selected);
  if(!owned(i)) {toast('来源不在身上，未执行','error');return;}
  if(i.type==='equipment') {
    const next=!i.equipped;
    if(next) items.filter(j=>owned(j)&&j.slot===i.slot).forEach(j=>{j.equipped=false;j.source='pack';});
    i.equipped=next;i.source=next?'gear':'pack';
    toast((next?'已穿戴：':'已卸下：')+i.name);
  } else if(i.type==='consumable') {
    if(i.doses!==undefined) {
      if(i.doses<1) {toast('指定瓶已空，请明确选择其他来源','error');return;}
      i.doses--;toast(`${i.name} · 剩余${i.doses}剂`);
    } else {i.qty--;toast(`已使用：${i.name} · 剩余${i.qty}`);}
  } else {toast('这件物品不能直接使用','error');return;}
  closeContext();render();
}
function canCarry(delta,extraStacks=0) {
  return totalWeight()+delta<=state.capacity+0.00001 && stackCount()+extraStacks<=state.slotCapacity;
}
function transferQuantity(i,n,owner,source) {
  if(n===i.qty) {if(owner==='player'&&i.owner!=='player') i.acquiredOrder=++state.acquisition;i.owner=owner;i.source=source;i.equipped=false;return i;}
  i.qty-=n;
  const moved={...i,id:`${i.definition}_copy_${++state.serial}`,qty:n,owner,source,equipped:false,stats:i.stats.map(r=>[...r])};
  if(owner==='player') {moved.acquiredOrder=++state.acquisition;if(state.organization[i.id]?.favorite) state.organization[moved.id]={favorite:true};}items.push(moved);return moved;
}
function confirmAmount() {
  const c=state.context,i=getItem(c.item),n=Number($('#context-amount').value);
  if(!owned(i)||!Number.isInteger(n)||n<1||n>i.qty) {toast('数量或来源失效，未转移','error');return;}
  if(c.kind==='split') {
    if(i.doses!==undefined||i.slot||n===i.qty) {toast('只能拆分可堆叠物品的一部分','error');return;}
    if(stackCount()>=state.slotCapacity) {toast('背包格数不足，未拆分','error');return;}
    transferQuantity(i,n,'player','pack');toast('已拆分，数量守恒');
  } else {
    if(i.type==='quest'||i.id==='coin') {toast('这件物品不能通过此入口丢弃','error');return;}
    transferQuantity(i,n,'ground','ground');toast('已放在脚边，可从搜取页取回');
  }
  closeContext();render();
}
function takeLoot() {
  const i=getItem(state.lootSelected),n=Number($('#loot-amount')?.value);
  if(!i||i.owner!=='ground'||!Number.isInteger(n)||n<1||n>i.qty) {toast('来源或数量失效，未取走','error');return;}
  if(!canCarry(Number(i.weight)*n,1)) {toast('容量不足，物品仍在原处','error');return;}
  transferQuantity(i,n,'player','pack');state.lootAmount=1;render();toast('已取走实物，余量保持');
}
function addToBasket(id) {
  const i=getItem(id),n=(state.basket[id]||0)+1;
  if(!i||i.equipped||n>i.qty) {toast('无法加入：已穿戴或数量不足','error');return;}
  state.basket[id]=n;state.basketConsent[id]=protectedReasons(i).join('|');render();
}
function confirmTrade() {
  const entries=Object.entries(state.basket),sell=state.tradeMode==='sell';
  if(!entries.length) return;
  const valid=entries.every(([id,n])=>{
    const i=getItem(id);
    return i && i.owner===(sell?'player':'merchant') && !i.equipped && i.type!=='quest' && Number.isInteger(n)&&n>0&&n<=i.qty;
  });
  if(!valid) {toast('清单来源失效，未付款或转移','error');return;}
  const total=tradeTotal();
  if(sell&&entries.some(([id])=>protectedReasons(getItem(id)).join('|')!==(state.basketConsent[id]||''))) {toast('保护状态发生变化，请重新检查清单','error');return;}
  if((sell?state.merchantCoins:coins())<total) {toast(sell?'商人资金不足，实物与钱币未变':'钱币不足，实物与钱币未变','error');return;}
  const weight=entries.reduce((sum,[id,n])=>sum+Number(getItem(id).weight)*n,0);
  if(!sell&&!canCarry(weight,entries.length)) {toast('背包容量不足，未付款','error');return;}
  // All requirements precede the illustrative commit. No events expose a half-trade.
  for(const [id,n] of entries) {transferQuantity(getItem(id),n,sell?'merchant':'player',sell?'merchant':'pack');if(sell&&state.organization[id]) state.organization[id].ware=false;}
  getItem('coin').qty+=sell?total:-total;state.merchantCoins+=sell?-total:total;
  state.basket={};state.basketConsent={};render();toast(sell?`出售完成 · 获得${total}币`:`购买完成 · 支付${total}币`,'info','accepted');
}
function craft() {
  const costs=recipeCosts(state.craft),output=template(state.craft);
  if(!recipeReady(state.craft)) {toast('原料不足，未扣除任何物品','error');return;}
  const delta=Number(output.weight)-Object.entries(costs).reduce((w,[id,n])=>w+Number(template(id).weight)*n,0);
  const target=items.find(i=>i.owner==='player'&&i.definition===state.craft);
  if(!canCarry(delta,target?0:1)) {toast('产出容量不足，未扣原料','error');return;}
  for(const [def,n] of Object.entries(costs)) {
    let remaining=n;
    for(const i of items.filter(i=>owned(i)&&i.definition===def)) {const take=Math.min(remaining,i.qty);i.qty-=take;remaining-=take;if(!remaining) break;}
  }
  if(target) target.qty++;
  else items.push(cloneItem(state.craft,{id:`crafted_${++state.serial}`,owner:'player',source:'pack',qty:1,equipped:false}));
  completePreparation(state.craft,1);render();toast('加工完成 · 原料扣除，产出进入背包','info','accepted');
}

function onAction(a) {
  if(handleDecisionAction(a)) return;
  const i=getItem(state.selected);
  switch(a) {
    case 'close': returnToWorld();break;
    case 'equip':case 'use':useItem();break;
    case 'compare':state.compare=!state.compare;$('#item-detail').innerHTML=itemDetail(i);break;
    case 'context':if(owned(i)) showContext('menu');break;
    case 'cancel-context':closeContext();break;
    case 'bind-item':closeContext();state.batchMode=false;state.binding=true;render();break;
    case 'cancel-binding':state.binding=false;render();break;
    case 'clear-slot':delete bindings[state.selectedSlot];delete state.formsBySlot[state.selectedSlot];render();toast('快捷槽清空，物品保留');break;
    case 'sort':items.sort((a,b)=>a.type.localeCompare(b.type)||a.name.localeCompare(b.name));render();toast('已整理，身份和余量保留');break;
    case 'toggle-display':state.display=state.display==='list'?'grid':'list';render();break;
    case 'clear-filter':state.query='';state.filter='all';state.slotFilter='';state.container='all';state.listMode='all';render();break;
    case 'pocket':if(i?.equipped) {toast('先卸下这件装备','error');break;}if(owned(i)) i.source='pocket';closeContext();render();break;
    case 'split':if(owned(i)&&i.qty>1) showContext('split',{item:i.id});break;
    case 'drop-dialog':if(owned(i)) showContext('drop',{item:i.id});break;
    case 'confirm-amount':confirmAmount();break;
    case 'source-settings':openForms();break;
    case 'cancel-forms':state.forms=false;renderSelector();break;
    case 'close-drawer':state.slotPanel=false;state.drawer=null;renderSelector();break;
    case 'read':state.drawer='read';state.forms=false;state.slotPanel=false;renderSelector();break;
    case 'loot':state.drawer='loot';state.forms=false;state.slotPanel=false;renderSelector();break;
    case 'buff-detail':state.drawer='buff';state.forms=false;state.slotPanel=false;renderSelector();break;
    case 'take-loot':takeLoot();break;
    case 'full-pack-demo':state.fullPackDemo=!state.fullPackDemo;state.capacity=state.fullPackDemo?totalWeight():(state.stress?500:40);render();toast(state.fullPackDemo?'容量设为当前重量，仅用于满包样例':`恢复样例容量${state.capacity}`);break;
    case 'learn-perk':state.perkPreview=true;render();break;
    case 'confirm-perk':if(!state.perk&&state.points>0) {state.perk=true;state.points--;render();toast('已学习战斗调息，未回满体力');}break;
    case 'perk-detail':toast('预览条件：已掌握基础，其他节点仅为布局示例');break;
    case 'technique':toast('武技每组合最多两招，不占快捷槽');break;
    case 'track':state.tracked=!state.tracked;render();toast(state.tracked?'已追踪目标':'已取消追踪');break;
    case 'waypoint':toast('个人路标示意，不揭示未知地形');break;
    case 'craft':craft();break;
    case 'basket-add':addToBasket(state.tradeSelected);break;
    case 'basket-clear':state.basket={};state.basketConsent={};render();break;
    case 'trade-confirm':confirmTrade();break;
    case 'recipe-locked':toast('尚未学会：需探索记录或训练，原料不会授予知识');break;
    case 'course-demo':toast('课程入口示意：正式版由训练服务核验并付款');break;
    case 'journal-info':toast('此处展示手札分组，示例记录没有更多分支');break;
    case 'save':case 'load':toast('存读档入口示意，不访问正式存档');break;
    case 'new':showContext('new');break;
    case 'reset-demo':location.reload();break;
    case 'exit':toast('退出入口示意，不关闭浏览器');break;
    case 'motion':document.body.classList.toggle('reduced');$('#motion-setting').textContent=document.body.classList.contains('reduced')?'开启':'关闭';break;
    case 'bindings-demo':toast('改键入口示意；E 与 1 始终为两个独立槽');break;
  }
}

function modalOpen() {return !!state.context && state.context.kind!=='menu';}
function trapTab(e,root) {
  const nodes=[...root.querySelectorAll('button:not(:disabled),input:not(:disabled),select,summary')].filter(n=>n.getClientRects().length&&!n.closest('[inert]'));
  if(!nodes.length) return;
  const at=nodes.indexOf(document.activeElement);
  if(at<0||!e.shiftKey&&at===nodes.length-1||e.shiftKey&&at===0) {e.preventDefault();nodes[e.shiftKey?nodes.length-1:0].focus();}
}

// Capture input before view handlers when an exclusive confirmation is open.
document.addEventListener('click',e=>{
  if(modalOpen()&&!e.target.closest('#context')&&!e.target.closest('#threat-demo')) {e.preventDefault();e.stopImmediatePropagation();return;}
  const map=e.target.closest('[data-map]');
  if(map) {state.mapPin=map.dataset.map;render();return;}
  const b=e.target.closest('button');
  if(!b||b.disabled) return;
  if(state.context?.kind==='menu'&&!b.closest('#context')) closeContext();
  if(b.dataset.demo) {openView(b.dataset.demo);return;}
  if(b.dataset.view) {openView(b.dataset.view);return;}
  if(b.dataset.item) {if(state.batchMode) refreshBatchSelection(b.dataset.item);else selectInventoryItem(b.dataset.item);return;}
  if(b.dataset.mapFilter) {state.mapFilter=b.dataset.mapFilter;render();return;}
  if(b.dataset.mapSource) {const place=mapPlaces[b.dataset.mapSource]||mapPlaces.archive;ruleGlossary.mapRecord={title:place.title+' · 记录来源',body:place.source+'。'+place.detail,note:'地图为结构示意；不提供未知目标的真实坐标。关闭后回到原地图与缩放。'};state.helpTopic='mapRecord';state.drawer='help';renderSelector();return;}
  if(b.dataset.explain) {state.helpTopic=b.dataset.explain;state.drawer='help';state.forms=false;state.slotPanel=false;renderSelector();return;}
  if(b.dataset.pin) {pinGoal(b.dataset.pin);render();return;}
  if(b.dataset.filter) {state.filter=b.dataset.filter;state.slotFilter='';render();return;}
  if(b.dataset.container) {state.container=b.dataset.container;render();return;}
  if(b.dataset.skill) {state.skill=b.dataset.skill;render();return;}
  if(b.dataset.slot) {state.selectedSlot=b.dataset.slot;state.forms=false;state.drawer=null;state.slotPanel=true;updateHUDOnly();return;}
  if(b.dataset.bindSlot) {
    const k=b.dataset.bindSlot;
    if(!state.binding&&state.skill==='breaker') {toast('武技由连招发动，不绑定快捷槽');return;}
    if(state.binding&&!owned(getItem(state.selected))) {toast('指定来源失效');return;}
    bindings[k]=state.binding?{kind:'item',id:state.selected}:{kind:'ability',id:state.skill};
    delete state.formsBySlot[k];state.selectedSlot=k;state.binding=false;render();toast(`已绑定 ${k}，其他槽未变`);return;
  }
  if(b.dataset.form) {
    const f=formCatalog(state.selectedSlot).find(f=>f.id===b.dataset.form);
    if(!f||f.reason) {toast(f?.reason||'形式已失效');return;}
    state.formsBySlot[state.selectedSlot]=f.id;state.forms=false;state.slotPanel=false;if(state.view==='hud') updateHUDOnly();else render();toast(`已固定：${f.name} · 未施放，未消费`);return;
  }
  if(b.dataset.craft) {state.craft=b.dataset.craft;render();return;}
  if(b.dataset.dialogue) {state.dialogue=b.dataset.dialogue;render();return;}
  if(b.dataset.tradeMode) {state.tradeMode=b.dataset.tradeMode;state.basket={};state.basketConsent={};render();return;}
  if(b.dataset.tradeItem) {
    state.tradeSelected=b.dataset.tradeItem;
    // Keep the clicked entry alive until native dblclick has been delivered.
    document.querySelectorAll('[data-trade-item]').forEach(n=>n.classList.toggle('selected',n===b));
    const temp=document.createElement('div');temp.innerHTML=trade();
    $('.trade-inspect').innerHTML=temp.querySelector('.trade-inspect').innerHTML;return;
  }
  if(b.dataset.removeBasket) {delete state.basket[b.dataset.removeBasket];render();return;}
  if(b.dataset.lootItem) {state.lootSelected=b.dataset.lootItem;state.lootAmount=1;renderSelector();return;}
  if(b.dataset.action==='gear') {state.slotFilter=b.dataset.value;state.filter='equipment';state.container='all';state.query='';render();return;}
  if(b.dataset.action) onAction(b.dataset.action);
},true);

document.addEventListener('dblclick',e=>{
  if(modalOpen()||state.view==='inventory'&&state.batchMode) return;
  const tile=e.target.closest('[data-item]'), sale=e.target.closest('[data-trade-item]');
  if(tile) {state.selected=tile.dataset.item;useItem();}
  if(sale) addToBasket(sale.dataset.tradeItem);
});
document.addEventListener('contextmenu',e=>{
  if(modalOpen()) {e.preventDefault();return;}
  const tile=e.target.closest('[data-item]'),slot=e.target.closest('[data-bind-slot]');
  if(tile) {e.preventDefault();selectInventoryItem(tile.dataset.item);showContext('menu');}
  else if(slot) {e.preventDefault();delete bindings[slot.dataset.bindSlot];delete state.formsBySlot[slot.dataset.bindSlot];render();toast('已清除这个槽的绑定');}
  else if(e.target.closest('.map-art')) e.preventDefault();
});
document.addEventListener('input',e=>{
  if(modalOpen()&&!e.target.closest('#context')) return;
  if(e.target.id==='item-search') {state.query=e.target.value;refreshInventoryList();}
  if(e.target.id==='loot-amount') state.lootAmount=Number(e.target.value);
});
document.addEventListener('change',e=>{
  if(modalOpen()) return;
  if(e.target.id==='actor-mode') {state.awake=e.target.value==='awakened';render();}
  if(e.target.id==='list-mode') {state.listMode=e.target.value;render();}
  if(e.target.id==='inventory-sort') {state.inventorySort=e.target.value;render();}
  if(e.target.id==='hud-mode') {state.hudMode=e.target.value;renderHUD();}
  if(e.target.id==='hud-setting') $('#hud').style.setProperty('--hud-scale',Number(e.target.value)/100);
  if(e.target.dataset.goalAmount) {const g=state.goals.find(g=>g.id===e.target.dataset.goalAmount),n=Number(e.target.value);if(g&&Number.isInteger(n)&&n>=1&&n<=9) {g.amount=n;render();}else toast('目标份数须为1—9','error');}
  if(e.target.id==='ui-volume') state.uiVolume=Number(e.target.value)/100;
  if(e.target.id==='font-setting') $('#stage').style.setProperty('--type-scale',Number(e.target.value)/100);
  if(e.target.id==='contrast-setting') $('#stage').classList.toggle('high-contrast',e.target.value==='high');
});
$('#stress-demo').addEventListener('click',()=>{if(!modalOpen()) addStressFixture();});
$('#status-demo').addEventListener('click',()=>{if(modalOpen())return;state.statusFixture=!state.statusFixture;$('#status-demo').textContent=state.statusFixture?'收起复合状态':'复合状态样例';render();});
$('#threat-demo').addEventListener('click',()=>{state.threat=!state.threat;if(state.threat) state.hp=Math.max(1,state.hp-8);render();});
$('#field-demo').addEventListener('click',()=>{if(modalOpen())return;state.field=!state.field;$('#field-demo').textContent=state.field?'火阵条件：有':'火阵条件：无';render();});

document.addEventListener('keydown',e=>{
  const k=e.key.toUpperCase();
  if(k==='ESCAPE') {
    e.preventDefault();
    if(state.threat) {returnToWorld();return;}
    if(state.context) {closeContext();return;}
    if(state.forms||state.slotPanel||state.drawer) {state.forms=false;state.slotPanel=false;state.drawer=null;renderSelector();return;}
    if(state.binding) {state.binding=false;render();return;}
    openView(state.view==='hud'?'settings':'hud');return;
  }
  if(modalOpen()) {if(k==='TAB') trapTab(e,$('#context'));else if(!e.target.matches('input,button')) e.preventDefault();return;}
  if(k==='TAB'&&(state.forms||state.slotPanel||state.drawer)) {trapTab(e,$('#selector'));return;}
  if(k==='TAB'&&state.view!=='hud') {trapTab(e,$('.menu'));return;}
  if(e.target.matches('input,select,textarea')||e.repeat) return;
  if(k==='SHIFT'&&state.view==='inventory') {state.compare=true;$('#item-detail').innerHTML=itemDetail(getItem(state.selected));return;}
  if(state.forms&&keys.includes(k)) {e.preventDefault();state.selectedSlot=k;openForms();renderHUD();return;}
  if(k==='G'&&state.view==='hud') {e.preventDefault();if(state.forms){state.forms=false;renderSelector();}else openForms();return;}
  const dest={I:'inventory',O:'inventory',N:'inventory',K:'skills',P:'character',J:'journal',M:'map'};
  if(dest[k]) {
    e.preventDefault();
    if(['I','O','N'].includes(k)) {
      const closing=state.view==='inventory'&&state.inventoryEntry===k;
      state.inventoryEntry=k;state.filter=k==='O'?'equipment':k==='N'?'consumable':'all';state.slotFilter='';state.container='all';
      openView(closing?'hud':'inventory');return;
    }
    openView(state.view===dest[k]?'hud':dest[k]);return;
  }
  if(k==='TAB'&&state.view==='hud') {e.preventDefault();openView(state.lastView);return;}
  if(k==='F'&&state.view==='hud') {onAction('read');return;}
  if(keys.includes(k)&&state.view==='hud') {state.selectedSlot=k;updateHUDOnly();toast('原型只预览当前槽，未施放或消费');}
});
document.addEventListener('keyup',e=>{if(e.key==='Shift'&&state.compare) {state.compare=false;if(state.view==='inventory') $('#item-detail').innerHTML=itemDetail(getItem(state.selected));}});
window.addEventListener('blur',()=>{state.compare=false;mapDrag=null;if(middleHeld){middleHeld=false;state.forms=false;renderSelector();}});

let mapDrag=null, middleHeld=false;
document.addEventListener('wheel',e=>{
  if(modalOpen()) return;
  const map=e.target.closest('.map-art');
  if(map) {e.preventDefault();state.mapZoom=Math.min(2.5,Math.max(1,state.mapZoom+(e.deltaY<0?.15:-.15)));map.setAttribute('viewBox',`${state.mapX} ${state.mapY} ${1000/state.mapZoom} ${600/state.mapZoom}`);return;}
  if(state.view!=='hud'||state.forms||state.drawer||state.slotPanel||!e.target.closest('#stage')) return;
  const ready=formCatalog(state.selectedSlot).filter(f=>!f.reason);
  if(!ready.length) return;
  e.preventDefault();const at=ready.findIndex(f=>f.id===currentForm(state.selectedSlot)?.id),next=ready[(Math.max(0,at)+(e.deltaY>0?1:ready.length-1))%ready.length];
  state.formsBySlot[state.selectedSlot]=next.id;updateHUDOnly();
},{passive:false});
document.addEventListener('pointerdown',e=>{
  if(modalOpen()) return;
  const map=e.target.closest('.map-art');
  if(map&&[1,2].includes(e.button)) {e.preventDefault();mapDrag={x:e.clientX,y:e.clientY,ox:state.mapX,oy:state.mapY,map};map.setPointerCapture(e.pointerId);return;}
  if(e.button===1&&state.view==='hud'&&e.target.closest('#stage')) {e.preventDefault();middleHeld=true;openForms();}
});
document.addEventListener('pointermove',e=>{if(!mapDrag) return;const d=mapDrag,ratio=1000/state.mapZoom/d.map.getBoundingClientRect().width;state.mapX=Math.max(-200,Math.min(800,d.ox-(e.clientX-d.x)*ratio));state.mapY=Math.max(-150,Math.min(480,d.oy-(e.clientY-d.y)*ratio));d.map.setAttribute('viewBox',`${state.mapX} ${state.mapY} ${1000/state.mapZoom} ${600/state.mapZoom}`);});
document.addEventListener('pointerup',e=>{
  mapDrag=null;
  if(e.button!==1||!middleHeld) return;
  middleHeld=false;
  const target=e.target.closest('[data-form]');
  const form=target?formCatalog(state.selectedSlot).find(f=>f.id===target.dataset.form):null;
  if(form&&!form.reason) state.formsBySlot[state.selectedSlot]=form.id;
  state.forms=false;updateHUDOnly();
});
setInterval(()=>{state.minute++;document.querySelectorAll('[data-clock]').forEach(n=>n.textContent=clock());},1000);
items.forEach((i,index)=>{if(i.acquiredOrder===undefined) i.acquiredOrder=index;});
state.acquisition=items.length;
render(false);
