/* UI concept only. All data below are illustrative, reset on reload and never reach Godot saves. */
const $=s=>document.querySelector(s);
const paths={sword:'M5 3l14 14m-5-1l4-4M3 21l4-4m-3-2l5 5M6 3l-3 3 10 10 3-3z',shield:'M12 3l8 3v6c0 5-8 9-8 9s-8-4-8-9V6z',flame:'M12 2c3 5-2 7 2 10 2-1 3-3 3-5 4 5 4 8 2 11s-10 5-13 0S8 8 12 2z',flask:'M9 2h6m-5 0v7l-5 9q-1 3 2 3h10q3 0 2-3l-5-9V2M7 15h10',bottle:'M9 2h6v5l3 4v10H6V11l3-4zM7 13h10',drop:'M12 2C9 8 4 12 4 16a8 8 0 0016 0c0-4-5-8-8-14z',coat:'M8 3l4 2 4-2 5 5-4 4v9H7v-9L3 8zM12 5v15',bag:'M7 7V5a5 5 0 0110 0v2M6 6h12l3 15H3zM8 11h8v6H8z',leaf:'M20 3C5 2 1 11 7 16c6 6 14-3 13-13zM4 21L17 6',coin:'M20 12a8 8 0 11-16 0 8 8 0 0116 0M12 7v10M8 10h8M8 14h8',book:'M3 4h7l2 2 2-2h7v16h-7l-2 2-2-2H3zM12 6v14',spark:'M12 2l2 7 7 3-7 2-2 8-2-8-8-2 8-3z',ring:'M18 13a6 6 0 11-12 0 6 6 0 0112 0M8 6l4-4 4 4-4 4z',bow:'M5 3q17 9 0 18M5 3l8 9-8 9M4 12h17m-4-3l4 3-4 3',hammer:'M3 5l5-3 8 8-5 5zM12 13l8 8',map:'M3 5l6-3 6 3 6-3v17l-6 3-6-3-6 3zM9 2v17m6-14v17',eye:'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12M15 12a3 3 0 11-6 0 3 3 0 016 0',clock:'M20 12a8 8 0 11-16 0 8 8 0 0116 0M12 7v5l3 2',heart:'M12 21L3 12C-2 5 7-1 12 6c5-7 14-1 9 6z',stamina:'M14 2L5 13h6l-1 9 9-13h-6z',helmet:'M4 15v-5a8 8 0 0116 0v5l-4-1v7H8v-7zM4 10h16',boots:'M7 3h8v12l5 3v3H4v-7h3z',hand:'M7 21L3 12l2-1 3 4V5h2v7-9h2v9-8h2v8-6h2v11l-3 4z',arrow:'M4 20L20 4M12 4h8v8M4 13v7h7',grain:'M12 22V3M12 8C3 8 5 2 5 2s7-1 7 6m0 6C2 14 3 8 3 8s9-1 9 6m0 5c10 0 9-6 9-6s-9-1-9 6m0-11c9 0 7-6 7-6s-7-1-7 6',cloth:'M3 5l7-2 11 3-2 15-9-3-7 2zM10 3v15',rock:'M7 3l10 1 5 10-7 8L3 17 2 8zM7 3l5 9 10 2m-10-2l3 10m-3-10L2 8',cup:'M4 5h13v8a6 6 0 01-12 0zM17 7h2a3 3 0 010 6h-2M4 21h13',skull:'M5 16a9 9 0 1114 0l-2 1v5H7v-5zM8 11h1m6 0h1m-6 9v2m4-2v2',plus:'M12 4v16M4 12h16'};
const icon=n=>`<svg viewBox="0 0 24 24" aria-hidden="true"><path d="${paths[n]||paths.rock}"/></svg>`;
const key=x=>`<kbd>${x}</kbd>`;
const keys=['Q','E','R','1','2','3','4','5','6','7','8','9','0'];
const items=[
{id:'sabre',name:'驿路短刀',type:'equipment',icon:'sword',qty:1,slot:'主手',weight:'1.8',value:8,lore:'旧驿路上回收的短刀。刃口已有磨痕，握柄仍然结实。',stats:[['物理伤害','29'],['稳定削减','24'],['轻击体力','12']],equipped:true},
{id:'coat',name:'粗布护衣',type:'equipment',icon:'coat',qty:1,slot:'躯干',weight:'3.2',value:8,lore:'双层布料在肘部做了补缀。能挡住擦伤，挡不住一记完整的重击。',stats:[['物理减伤','8%'],['稳定抗性','12']],equipped:true},
{id:'bow',name:'灰河短弓',type:'equipment',icon:'bow',qty:1,slot:'主手',weight:'2.1',value:12,lore:'猎队常用的短弓。放箭前仍须准备实有箭矢。',stats:[['远程伤害','25'],['有效射程','18步'],['弹药','箭矢 ×1']]},
{id:'shield',name:'灰河木盾',type:'equipment',icon:'shield',qty:1,slot:'副手',weight:'3.0',value:9,lore:'盾面被河水浸过，边沿重新包了铁。',stats:[['格挡减伤','45%'],['稳定抗性','18'],['体力回复','−5%']]},
{id:'spare_coat',name:'旧守路队护衣',type:'equipment',icon:'coat',qty:1,slot:'躯干',weight:'3.5',value:8,lore:'肩上的旧记号被仔细拆掉了。',stats:[['物理减伤','10%'],['稳定抗性','14']]},
{id:'ration',name:'烤饼',type:'consumable',icon:'grain',qty:2,weight:'.3',value:2,lore:'用谷粮烤成的硬饼。能充饥，也能改善一段时间内的恢复。',stats:[['饱食恢复','+35'],['食物持续','120秒']]},
{id:'water',name:'饮用水',type:'consumable',icon:'drop',qty:3,weight:'.5',value:1,lore:'已经净化的饮用水。喝下去的水不能再拿去加工。',stats:[['饮水恢复','+40'],['水囊容量','3 / 4']]},
{id:'tea',name:'醒神茶',type:'consumable',icon:'cup',qty:1,weight:'.3',value:3,lore:'入口微苦。缓解疲惫，不能代替真正的休息。',stats:[['疲劳','−20']]},
{id:'spray_a',name:'树脂喷剂 · I',type:'consumable',icon:'flask',qty:1,doses:2,weight:'.7',value:4,lore:'瓶口有一道浅刻痕。剩余剂量跟随这只瓶子，耗尽后不会自动换瓶。',stats:[['剩余剂量','2 / 3'],['投送方式','持续喷洒'],['法力消耗','0']]},
{id:'spray_b',name:'树脂喷剂 · II',type:'consumable',icon:'flask',qty:1,doses:3,weight:'.7',value:4,lore:'尚未用过的另一只瓶子。与已编组的喷剂分别保存余量。',stats:[['剩余剂量','3 / 3'],['投送方式','持续喷洒'],['法力消耗','0']]},
{id:'oil',name:'油瓶',type:'consumable',icon:'bottle',qty:2,weight:'.6',value:3,lore:'投出整件实物，在远处形成油性覆盖。不是持续喷洒的替代品。',stats:[['消耗','整瓶 ×1'],['投送方式','投掷']]},
{id:'rag',name:'火抹布',type:'consumable',icon:'cloth',qty:1,weight:'.2',value:4,lore:'涂在当前具体武器上。材料所含的力量无需使用者先觉醒。',stats:[['作用','武器火焰涂附'],['消耗','抹布 ×1']]},
{id:'broth',name:'苦叶炖汤',type:'consumable',icon:'cup',qty:1,weight:'.5',value:4,lore:'温热的苦叶汤，适合回镇后慢慢喝。',stats:[['作用','饱食与恢复']]},
{id:'stone',name:'火石',type:'material',icon:'rock',qty:2,weight:'.2',value:3,lore:'炭屑与晶砂加工出的阵材。只有明确选择火石阵，才会在布阵时消耗。',stats:[['铭阵消耗','1火石 + 8MP'],['用途','火石阵']]},
{id:'cloth',name:'布料',type:'material',icon:'cloth',qty:3,weight:'.1',value:1,lore:'留一份用于档案压印台的手工修复；也可制成涂附抹布。',stats:[['用途','制造 / 检修']]},
{id:'resin',name:'树脂',type:'material',icon:'drop',qty:2,weight:'.1',value:2,lore:'从树木与旧猎营收集的粘稠树脂。',stats:[['用途','喷剂 / 涂料']]},
{id:'charcoal',name:'炭屑',type:'material',icon:'rock',qty:2,weight:'.1',value:1,lore:'能换到一笔有限的学费，也能留作加工原料。',stats:[['用途','加工 / 燃料']]},
{id:'herb',name:'苦叶',type:'material',icon:'leaf',qty:2,weight:'.1',value:3,lore:'苦叶可以烹煮，也可交给需要药草的镇民。',stats:[['用途','炼金 / 炊事']]},
{id:'book',name:'封锁名册',type:'quest',icon:'book',qty:1,weight:'.1',value:0,lore:'姓名、班次与仍未撤销的命令，写在同一页上。它是一份证据，不是新的命令。',stats:[['记录','已阅读'],['归属','探索证据']]},
{id:'coin',name:'河谷币',type:'material',icon:'coin',qty:18,weight:'0',value:1,lore:'磨损的地方铸币。钱袋里有多少，就只能付出多少。',stats:[['持有','18']]}
];
items.push({id:'crystal',name:'晶砂',type:'material',icon:'rock',qty:3,weight:'.2',value:3,lore:'细碎的晶体砂粒，制造与刻阵都需要真实取用。',stats:[['用途','阵材加工']]},{id:'ash',name:'炭灰',type:'material',icon:'rock',qty:3,weight:'.1',value:1,lore:'炭屑加工后的细灰。',stats:[['用途','阵材加工']]});
items.forEach(i=>i.source=i.equipped?'gear':i.type==='consumable'&&i.id!=='spray_b'?'pocket':'pack');
const abilities={inscribe:{name:'铭刻',icon:'spark',magic:true,desc:'基础操作决定法阵的结构，当前选择的真实材料决定法阵性质。',cost:'8 MP + 1火石'},spray:{name:'喷洒',icon:'flask',magic:false,desc:'持续释放指定瓶内剂量。普通喷洒不需要魔力，魔法强化须另验资格与资源。',cost:'每次1剂 · 0 MP'},ignite:{name:'火花',icon:'flame',magic:true,desc:'独立火花与火阵内的火球来自同一操作；当前真实现场决定可用形式。',cost:'4 MP / 火阵内12 MP'},breaker:{name:'破势斩',icon:'sword',magic:false,desc:'轻→重完成后，窗口内Ctrl+左键发动。短按轻式26体力，长按重式34体力；不会占用法术或物品槽。',cost:'26 / 34体力'}};

items.forEach(i=>{i.owner="player";i.definition=i.id});
