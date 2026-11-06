class_name ExpeditionScreen
extends VBoxContainer
## Declarative, independently previewable screen; a presenter binds data and requests.
var tabs: HBoxContainer:
	get: return $Tabs
var tools: HBoxContainer:
	get: return $Tools
var search: LineEdit:
	get: return $Tools/Search
var status: Label:
	get: return $Status
var rows: VBoxContainer:
	get: return $Columns/List/Rows
var detail: VBoxContainer:
	get: return $Columns/Details/Detail
var footer: HBoxContainer:
	get: return $Footer
