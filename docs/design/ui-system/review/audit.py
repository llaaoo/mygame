"""Record design gaps in the v1 HTML concept; not Godot regression tests."""
import argparse
import json
from pathlib import Path
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('--url', default='http://127.0.0.1:8767/docs/design/ui-system/')
parser.add_argument('--out', default='/tmp/grayriver-ui-review')
args = parser.parse_args()
out = Path(args.out)
out.mkdir(parents=True, exist_ok=True)
observations, errors = [], []

def observe(code, requirement_met, evidence):
    observations.append({'id': code, 'requirement_met': requirement_met, 'evidence': evidence})

with sync_playwright() as p:
    browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox'])
    page = browser.new_page(viewport={'width': 1440, 'height': 1000}, device_scale_factor=1)
    page.on('pageerror', lambda e: errors.append(str(e)))

    def fresh():
        page.goto(args.url, wait_until='networkidle')
        page.evaluate('document.fonts.ready')

    fresh()
    page.keyboard.press('i')
    page.keyboard.press('Tab')
    observe('keyboard-focus', page.locator('.menu').count() == 1, {'after_I_Tab': page.locator('.menu h1').all_text_contents()})

    fresh()
    page.keyboard.press('i')
    page.locator('#item-search').fill('喷剂')
    before = page.locator('[data-item]').count()
    page.locator('[data-item="spray_a"]').click()
    observe('search-persistence', page.locator('#item-search').input_value() == '喷剂' and page.locator('[data-item]').count() == before,
            {'matches_before':before,'matches_after_selection':page.locator('[data-item]').count(),'query_after_selection':page.locator('#item-search').input_value()})

    fresh()
    page.keyboard.press('i')
    page.locator('[data-item="bow"]').dblclick(delay=80)
    observe('double-click-equip', '灰河短弓' in page.locator('[data-value="主手"]').get_attribute('title'),
            {'mainhand_after_double_click':page.locator('[data-value="主手"]').get_attribute('title')})

    fresh()
    page.keyboard.press('i')
    page.locator('[data-value="头部"]').click()
    observe('equipment-slot-filter', page.locator('[data-item]').count() == 0,
            {'head_slot_has_no_owned_match':True,'items_displayed':page.locator('[data-item]').count(),'detail_title':page.locator('#item-detail h2').inner_text()})

    fresh()
    page.locator('[data-demo="character"]').click()
    before = page.locator('.top-data').inner_text()
    page.locator('[data-action="learn-perk"]').click()
    after = page.locator('.top-data').inner_text()
    observe('perk-preview-first', after == before, {'before':before,'after_one_node_click':after})

    fresh()
    page.locator('#actor-mode').select_option('awakened')
    page.keyboard.press('g');page.keyboard.press('q');page.locator('[data-form="fire"]').click()
    page.keyboard.press('g')
    selected_marks = page.locator('#selector [aria-checked="true"],#selector [aria-selected="true"],#selector .selected,#selector .active').count()
    observe('current-form-feedback', selected_marks > 0, {'selection_marks_after_reopening':selected_marks})
    page.screenshot(path=str(out/'selected-form.png'))

    fresh()
    page.locator('[data-demo="settings"]').click()
    page.locator('[data-action="new"]').click()
    page.locator('#motion-setting').click()
    observe('confirmation-input-scope', page.locator('#motion-setting').inner_text() == '关闭',
            {'background_setting_after_click_with_confirmation_open':page.locator('#motion-setting').inner_text(),'confirmation_still_open':page.locator('[data-action="reset-demo"]').count()==1})

    fresh()
    page.locator('#actor-mode').select_option('awakened')
    page.keyboard.press('k');page.locator('[data-skill="inscribe"]').click();page.locator('[data-bind-slot="1"]').click()
    page.keyboard.press('Escape');page.locator('[data-slot="1"]').click();page.keyboard.press('Escape');page.keyboard.press('g')
    observe('all-slots-source-access', page.locator('#selector .eyebrow').inner_text().startswith('1 /'),
            {'selector_slot_after_selecting_1_and_G':page.locator('#selector .eyebrow').inner_text()})

    layouts=[]
    for width,height in [(960,720),(1440,900),(1920,1080)]:
        page.set_viewport_size({'width':width,'height':height})
        fresh();page.locator('[data-demo="settings"]').click();page.locator('#font-setting').select_option('125')
        page.locator('[data-demo="skills"]').click()
        bounds=page.locator('.binding-row').evaluate('''row=>{const end=row.lastElementChild.getBoundingClientRect(),host=row.closest('.content-scroll').getBoundingClientRect();return {last_slot_right:end.right,clip_right:host.right,last_slot_bottom:end.bottom,clip_bottom:host.bottom,last_slot_width:end.width}}''')
        observe(f'bindings-visible-{width}', bounds['last_slot_right'] <= bounds['clip_right']+.5 and bounds['last_slot_bottom'] <= bounds['clip_bottom']+.5, bounds)
        if width==960:
            page.wait_for_timeout(2500)
            page.screenshot(path=str(out/'skills-small-large-text.png'))
        page.locator('[data-demo="inventory"]').click();page.locator('[data-item="bow"]').click()
        m=page.locator('[data-action="equip"]').evaluate('''b=>{const r=b.getBoundingClientRect(),p=b.closest('.detail-pane').getBoundingClientRect();return {action_bottom:r.bottom,detail_bottom:p.bottom,action_width:r.width,action_height:r.height}}''')
        observe(f'primary-action-visible-{width}', m['action_bottom']<=m['detail_bottom']+.5,m)
        page.locator('[data-demo="hud"]').click()
        metrics=page.locator('#stage').evaluate('''stage=>{const all=[...stage.querySelectorAll('button')].filter(b=>b.getClientRects().length);const short=all.filter(b=>{const r=b.getBoundingClientRect();return r.width<40||r.height<40});const fonts=[...stage.querySelectorAll('small,kbd,.quick-hint,.meter span')].map(b=>parseFloat(getComputedStyle(b).fontSize));return {buttons:all.length,buttons_below_40:short.length,min_label_px:Math.min(...fonts)}}''')
        layouts.append({'viewport':[width,height],'text_scale':1.25,**metrics})
    # Palette pair analysis is explicit, not a claim about every rendered pixel.
    def luminance(hex_color):
        vals=[int(hex_color[i:i+2],16)/255 for i in (0,2,4)]
        vals=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in vals]
        return sum(v*w for v,w in zip(vals,(.2126,.7152,.0722)))
    palette={c:round((luminance(c)+.05)/(luminance('101716')+.05),2) for c in ['e6e1d2','9aa59b','b96556','a5ae82','82a5ac']}
    browser.close()
report={'scope':'v1 standalone UI concept design review; observed gaps are intentionally recorded, not treated as passing gameplay checks','prototype_base_commit':'23036506b237041c9c786019b8fba39b25cff44a','observations':observations,'layout_metrics':layouts,'palette_contrast_on_ink':palette,'javascript_errors':errors}
(out/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(report,ensure_ascii=False,indent=2))
