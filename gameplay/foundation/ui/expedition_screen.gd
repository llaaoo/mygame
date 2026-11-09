class_name ExpeditionScreen
extends HBoxContainer
## The shell owns layout; presenters still own queries and domain requests.
var tabs: VBoxContainer:
	get: return $Navigation/Tabs
var tools: HBoxContainer:
	get: return $Content/Tools
var search: LineEdit:
	get: return $Content/Tools/Search
var status: Label:
	get: return $Content/Status
var rows: VBoxContainer:
	get: return $Content/Columns/List/Rows
var detail: VBoxContainer:
	get: return $Content/Columns/Details/Detail
var footer: VBoxContainer:
	get: return $Content/Footer
