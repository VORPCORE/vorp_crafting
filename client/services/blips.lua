Blips = {}

Blips.addBlipForCoords = function(_, blipname, bliphash, x, y, z)
	local blip = BlipAddForCoords(1664425300, x, y, z)
	SetBlipSprite(blip, bliphash, true)
	SetBlipScale(blip, 0.2)
	SetBlipName(blip, blipname)
end
