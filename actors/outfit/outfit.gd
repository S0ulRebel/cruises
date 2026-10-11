@tool
class_name Outfit
extends Resource
## A whole character as a list: which body, which pieces, what colour skin.
##
## This is what the workshop saves and what a spawner will hand to a Dresser. The captain is
## one fixed outfit; a crowd of zombies is a pool of pieces an outfit is rolled from.
##
## The pieces are their own .tres files in actors/outfit/pieces, so a coat fitted once is
## fitted in every outfit that wears it. An outfit only points at them.

## The rigged body everything is worn on.
@export_file("*.glb", "*.gltf", "*.tscn") var body := ""
@export var pieces: Array[OutfitPiece] = []
## Multiplies the colour of the body and of every piece marked `skin`. White leaves the texture
## exactly as painted.
@export var skin_colour := Color.WHITE


## External Resource entries are not reliably deep-copied by Array duplication.
## Each authoring session explicitly owns every mutable fit.
func working_copy() -> Outfit:
	var copy := Outfit.new()
	copy.body = body
	copy.skin_colour = skin_colour
	for piece in pieces:
		if piece != null:
			copy.pieces.append(piece.duplicate(true) as OutfitPiece)
	return copy


## The piece in `slot`, or null.
func piece_in(slot: String) -> OutfitPiece:
	for piece in pieces:
		if piece != null and piece.slot == slot:
			return piece
	return null
