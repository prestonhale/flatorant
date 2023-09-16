extends Line2D

@onready var timer = $Timer

func _ready():
	# Delete after timer
	timer.timeout.connect(queue_free)
	
