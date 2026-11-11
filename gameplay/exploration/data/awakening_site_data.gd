class_name AwakeningSiteData
extends Resource
## Immutable ritual definition. Permanent qualification belongs to ActorMagicState.
@export var id: String
@export var title: String
@export var pos := Vector2.ZERO
@export_multiline var description: String
@export var trial_claim: String
@export var required_claims: PackedStringArray=[]
@export var trial_method: FieldWorkMethod
@export var accept_method: FieldWorkMethod
@export_range(1,1000,1) var permanent_hp_cost := 10
@export_range(1,1000,.5) var permanent_stamina_cost := 10.0
@export_range(1,1000,1) var mana_base := 60

func validation_errors() -> Array[String]:
	var errors: Array[String]=[]
	if id.is_empty() or trial_claim.is_empty() or trial_claim==id or title.is_empty() or description.is_empty(): errors.append("Missing awakening identity, trial claim or description")
	if not pos.is_finite(): errors.append("Invalid awakening position")
	if required_claims.is_empty(): errors.append("Awakening requires explicit prior discoveries")
	if permanent_hp_cost<=0 or permanent_hp_cost>1000 or not is_finite(permanent_stamina_cost) or permanent_stamina_cost<=0 or permanent_stamina_cost>1000 or mana_base<=0 or mana_base>1000: errors.append("Invalid permanent awakening costs or mana baseline")
	for method in [trial_method,accept_method]:
		if not method or not method.validation_error().is_empty() or not method.fixed_duration or not method.material_costs.is_empty(): errors.append("Awakening needs fixed-duration, material-free preparation methods")
		elif not method.id.begins_with("awakening:"): errors.append("Awakening method identity must use the awakening namespace")
	if trial_method and accept_method and trial_method.id==accept_method.id: errors.append("Trial and permanent acceptance need different method identities")
	return errors

func fingerprint() -> Array:
	return [id,title,pos,description,trial_claim,required_claims.duplicate(),permanent_hp_cost,permanent_stamina_cost,mana_base,trial_method.fingerprint() if trial_method else [],accept_method.fingerprint() if accept_method else []]
