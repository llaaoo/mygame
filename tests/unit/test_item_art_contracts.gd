extends GutTest
## Artwork is definition metadata. Presentation never mutates inventory or the shared definition.
const ART := "res://content/art/third_party/lucide/swords.svg"
func test_optional_art_rejects_bad_authoring_without_loading_remote_or_non_image_resources() -> void:
 var item:=ItemData.new(); item.id="art-contract"
 assert_eq(item.illustration_error(),"")
 for path in ["https://example.invalid/sword.png","res://missing-sword.png","res://content/foundation/items.tres"]:
  item.illustration_path=path
  assert_true(item.illustration_error().contains(path),"The author needs the exact invalid asset path")
 item.illustration_path=ART
 assert_eq(item.illustration_error(),"")
func test_selected_art_can_change_back_to_an_unillustrated_item_without_stale_image_or_definition_writes() -> void:
 var illustrated:=ItemData.new(); illustrated.id="illustrated"; illustrated.illustration_path=ART
 var plain:=ItemData.new(); plain.id="plain"
 var view:=ItemArtView.new(); add_child_autofree(view)
 view.present(illustrated,"owned.1")
 assert_true(view.uses_illustration)
 assert_eq(view.texture.resource_path,ART)
 assert_eq(view.get_meta("item_uid"),"owned.1")
 view.present(plain,"owned.2")
 assert_false(view.uses_illustration)
 assert_eq(view.item_id,"plain")
 assert_eq(view.get_meta("item_uid"),"owned.2")
 assert_not_null(view.texture,"Unillustrated items keep their existing item graphic")
 assert_eq(illustrated.illustration_path,ART)
 assert_eq(plain.illustration_path,"")
 assert_null(plain.icon,"Rendering a fallback must not write it into the shared definition")
