shader_type canvas_item;

// Size of polygon relative to the polygon that fits the viewport.
uniform float size : hint_range(0.0, 1.0) = 0.5;

// Number of sides of polygon
// 0: All of the image
// 1: Half of the image
// 2: Line
// 3: Triangle
// etc
uniform int sides : hint_range(0, 50) = 6;

// Rotation of the polygon
uniform float rotation : hint_range(-360.0, 360.0) = 0.0;

// Center point of the polygon
uniform float position_x : hint_range(-1.0, 1.5) = 0.5;
uniform float position_y : hint_range(-1.0, 1.5) = 0.5;

// The width of the border around the polygon. If 0.0, there is no border.
uniform float border_width : hint_range(0.0, 1.0) = 0.1;

// The color to modulate the border area.
uniform vec4 border_color : source_color = vec4(0.35, 0.35, 1.0, 1.0);

// Whether to ensure that the polygon is regular with respect
// to the actual viewport aspect ratio.
uniform bool maintain_aspect_ratio = true;

void fragment() {
	// Pull in the texture.
	COLOR = texture(TEXTURE, UV);

	// Most of the logic presumes that there is some kind of non 1:1 aspect
	// ratio and adjusts the texture to suit logic that must assume there is a
	// 1:1 aspect ratio. If the maintain_aspect_ratio option is turned off,
	// however, the logic will assume a 1:1 ratio without it being true. This
	// will distort the triangles such that the area of the erasure is
	// proportional to the area of the image.
	vec2 aspect_ratio = vec2(1.0, 1.0);
	if (maintain_aspect_ratio) {
		// Determine the difference in ratio of the texture to that of a square
		aspect_ratio = vec2(
			min(1.0, TEXTURE_PIXEL_SIZE.y / TEXTURE_PIXEL_SIZE.x),
			min(1.0, TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y)
		);
	}
	
	// Use that ratio to adjust the UV to one that reflects the UV if the
	// texture were actually that square. So, if the original texture was, say,
	// twice as wide as it is tall, the Y coordinate of the UV pair that would
	// otherwise go from 0.0 to 1.0 would now go from 0.25 to 0.75 since that
	// would be the UV values of the image if it were centered on such a square
	// that would fit it.
	vec2 adjusted_uv = vec2(
		((UV.x - position_x) * aspect_ratio.x) + 0.5,
		((UV.y - position_y) * aspect_ratio.y) + 0.5
	);
	
	// Transform UV from the range (0.0, 1.0) to the range (-1.0, 1.0)
	adjusted_uv.x = mix(-1.0, 1.0, adjusted_uv.x);
	adjusted_uv.y = mix(-1.0, 1.0, adjusted_uv.y);
	
	// Get the angle of the coordinate from the center and apply the user
	// provided rotation.
	float theta = atan(adjusted_uv.y, adjusted_uv.x) + (rotation * PI / 180.0);
	
	// Compute the inner angle of the requested polygon
	float angle = TAU / float(sides);
	
	// For convenience, half of that angle is also really useful.
	float half_angle = angle / 2.0;
	
	// Normalize as within half the angle of the corners of the shape.
	// For sides = 4, this effectively restricts it to one quadrant.
	// We add half the angle back so that our x axes runs through a point and
	// not the midpoint of a side. So when sides = 4, the resulting shape is a
	// diamond.
	theta = mod(theta, angle) + half_angle;
	
	// We want a scale of 0.0 to be the entire image. So, the corner of the
	// image should be on a tangent with a line on the shape. We should just
	// solve the polar equation for the polygon size given that the line to the
	// polygon edge, at the angle toward the corner, is the distance from the
	// center to that corner. Phew.
	float corner_theta = atan(-aspect_ratio.y, -aspect_ratio.x);
	corner_theta = mod(corner_theta, angle) + half_angle;
	
	// Compute the radius of the polygon that fits the original texture.
	// First, get the distance to the corner.
	float corner_d = distance(vec2(0.0, 0.0), -aspect_ratio);
	
	// Then solve for the overall radius of the polygon using the polar
	// equation for our n-sided polygon given our angle/half-angle, the angle
	// to the corner, and the expected distance to the edge of the polygon via
	// the distance to that corner.
	float max_radius = corner_d * cos(half_angle - abs(half_angle - corner_theta));
	
	// A scale of [0.0, 1.0] should return the range [full_polygon_radius, 0.0].
	// Our 'scale' is going to affect the size of the polygon.
	// If our 'scale' is 1.0, we want the smallest polygon, so invert the scale.
	// This is, then, the proportion of our largest polygon via 'max_radius'.
	float scale = size * max_radius;
	
	// Determine, given our current theta angle, the distance to the edge of the
	// polygon. This is just computing the hypotenuse of the right triangle that
	// fills this region of the polygon.
	float polygon_radius = scale / cos(half_angle - abs(half_angle - theta));
	
	// Determine the edges of the border
	float border_scale = (size - border_width) * max_radius;
	float border_radius = border_scale / cos(half_angle - abs(half_angle - theta));
	
	// Get the distance from our current UV point to the center (recall that our
	// UV is perhaps adjusted to reflect the aspect ratio of the texture, so we
	// use our adjusted_uv, here.)
	float d = distance(vec2(0.0, 0.0), adjusted_uv);
	
	// If the distance to the center is greater than the polygon radius, we are
	// outside the polygon. Void that color's alpha to hide it.
	if (d > polygon_radius) {
		COLOR.a = 0.0;
	}
	else if (d > border_radius) {
		// Modulate the border color
		vec4 modulated = vec4(border_color.rgb * border_color.a, 1.0);
		COLOR = mix(COLOR, modulated, border_color.a);
	}
}