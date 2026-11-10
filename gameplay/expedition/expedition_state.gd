class_name ExpeditionState
extends SaveRecord
## Durable pending rescue prevents saving at defeat from skipping the journey cost.
@export_storage var pending_rescue := false
