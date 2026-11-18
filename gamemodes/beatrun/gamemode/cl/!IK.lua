BeatrunIK = BeatrunIK or {}

-- NOTE: Left the comments because big scary math

-- Middle joint position for a two-bone chain root -> mid -> end when the end has to reach a new target.
-- Keeps the joint in its current bend plane, falls back to bending towards px/py/pz when the chain is straight
function BeatrunIK.SolveTwoBone(rx, ry, rz, mx, my, mz, ex, ey, ez, tx, ty, tz, px, py, pz)
	local l1 = math.sqrt((mx - rx) ^ 2 + (my - ry) ^ 2 + (mz - rz) ^ 2)
	local l2 = math.sqrt((ex - mx) ^ 2 + (ey - my) ^ 2 + (ez - mz) ^ 2)

	local ux, uy, uz = tx - rx, ty - ry, tz - rz
	local dist = math.sqrt(ux * ux + uy * uy + uz * uz)

	if dist < 1e-4 then return mx, my, mz, ex, ey, ez end

	ux, uy, uz = ux / dist, uy / dist, uz / dist

	local d = math.Clamp(dist, math.abs(l1 - l2) + 0.01, (l1 + l2) * 0.999)

	local vx, vy, vz = mx - rx, my - ry, mz - rz
	local along = vx * ux + vy * uy + vz * uz

	vx, vy, vz = vx - ux * along, vy - uy * along, vz - uz * along

	if vx * vx + vy * vy + vz * vz < 1e-4 then
		along = px * ux + py * uy + pz * uz
		vx, vy, vz = px - ux * along, py - uy * along, pz - uz * along
	end

	local vlen = math.sqrt(vx * vx + vy * vy + vz * vz)

	if vlen < 1e-6 then return mx, my, mz, ex, ey, ez end

	vx, vy, vz = vx / vlen, vy / vlen, vz / vlen

	local x = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
	local h = math.sqrt(math.max(l1 * l1 - x * x, 0))

	return rx + ux * x + vx * h, ry + uy * x + vy * h, rz + uz * x + vz * h, rx + ux * d, ry + uy * d, rz + uz * d
end

-- Shortest rotation taking direction a to direction b, as a row-major 3x3.
-- Optionally only a fraction of it and no more than maxangle radians
function BeatrunIK.MinArc(ax, ay, az, bx, by, bz, fraction, maxangle)
	local la = math.sqrt(ax * ax + ay * ay + az * az)
	local lb = math.sqrt(bx * bx + by * by + bz * bz)

	if la < 1e-6 or lb < 1e-6 then return 1, 0, 0, 0, 1, 0, 0, 0, 1 end

	ax, ay, az = ax / la, ay / la, az / la
	bx, by, bz = bx / lb, by / lb, bz / lb

	local cx, cy, cz = ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx
	local s = math.sqrt(cx * cx + cy * cy + cz * cz)

	if s < 1e-6 then return 1, 0, 0, 0, 1, 0, 0, 0, 1 end

	local c = ax * bx + ay * by + az * bz

	cx, cy, cz = cx / s, cy / s, cz / s

	if fraction or maxangle then
		local angle = math.min(math.atan2(s, c), maxangle or math.pi) * (fraction or 1)

		c, s = math.cos(angle), math.sin(angle)
	end

	local t = 1 - c

	return t * cx * cx + c, t * cx * cy - s * cz, t * cx * cz + s * cy,
		t * cx * cy + s * cz, t * cy * cy + c, t * cy * cz - s * cx,
		t * cx * cz - s * cy, t * cy * cz + s * cx, t * cz * cz + c
end

-- Big wall of text because sorse jank
-- BuildBonePositions can run more than once a frame: a bonemerged model with attachments makes the engine set up
-- the parent's bones again with another bone mask. Bones outside that mask aren't rebuilt and still hold what we wrote
-- last time, moving them again would apply the IK twice. So every pass first puts those bones back to the animation's
-- pose, and the IK always starts from the same input
local function BeginPass(ent)
	local saved = ent.BeatrunIKSaved

	if not saved then
		saved = {}
		ent.BeatrunIKSaved = saved
	end

	for bone, state in pairs(saved) do
		state.touched = false

		local m = ent:GetBoneMatrix(bone)
		if m and m == state.after then ent:SetBoneMatrix(bone, state.before) end
	end

	return saved
end

-- Use this instead of AddCallback("BuildBonePositions") for anything that moves bones with BeatrunIK.
-- late callbacks run after all the others, whatever order they were added in
function BeatrunIK.AddBoneCallback(ent, func, late)
	local callbacks = ent.BeatrunIKCallbacks

	if not callbacks then
		callbacks = {}
		ent.BeatrunIKCallbacks = callbacks
		ent.BeatrunIKLateCallbacks = {}

		local latecallbacks = ent.BeatrunIKLateCallbacks

		ent:AddCallback("BuildBonePositions", function(e, numbones)
			BeginPass(e)

			for _, f in ipairs(callbacks) do
				f(e, numbones)
			end

			for _, f in ipairs(latecallbacks) do
				f(e, numbones)
			end
		end)
	end

	local list = late and ent.BeatrunIKLateCallbacks or callbacks

	list[#list + 1] = func
end

-- Remembers the bone's pose from before this pass touched it, m is its current matrix
local function TrackBone(ent, bone, m)
	local saved = ent.BeatrunIKSaved or BeginPass(ent)
	local state = saved[bone]

	if not state then
		state = { before = Matrix(), after = Matrix() }
		saved[bone] = state
	end

	if not state.touched then
		state.before:Set(m)
		state.touched = true
	end

	return state
end

-- Replaces a bone's matrix, safe to run on every pass like MoveBone
function BeatrunIK.SetBoneMatrix(ent, bone, m)
	local cur = ent:GetBoneMatrix(bone)
	if not cur then return end

	local state = TrackBone(ent, bone, cur)

	ent:SetBoneMatrix(bone, m)
	state.after:Set(m)
end

-- Moves a bone by x -> q + R(x - p), rotating its orientation by R as well
function BeatrunIK.MoveBone(ent, bone, r11, r12, r13, r21, r22, r23, r31, r32, r33, px, py, pz, qx, qy, qz)
	local m = ent:GetBoneMatrix(bone)
	if not m then return end

	local state = TrackBone(ent, bone, m)

	local m11, m12, m13, tx, m21, m22, m23, ty, m31, m32, m33, tz = m:Unpack()

	tx, ty, tz = tx - px, ty - py, tz - pz

	m:SetUnpacked(
		r11 * m11 + r12 * m21 + r13 * m31, r11 * m12 + r12 * m22 + r13 * m32, r11 * m13 + r12 * m23 + r13 * m33, qx + r11 * tx + r12 * ty + r13 * tz,
		r21 * m11 + r22 * m21 + r23 * m31, r21 * m12 + r22 * m22 + r23 * m32, r21 * m13 + r22 * m23 + r23 * m33, qy + r21 * tx + r22 * ty + r23 * tz,
		r31 * m11 + r32 * m21 + r33 * m31, r31 * m12 + r32 * m22 + r33 * m32, r31 * m13 + r32 * m23 + r33 * m33, qz + r31 * tx + r32 * ty + r33 * tz,
		0, 0, 0, 1
	)

	ent:SetBoneMatrix(bone, m)
	state.after:Set(m)
end

function BeatrunIK.MoveBones(ent, bones, r11, r12, r13, r21, r22, r23, r31, r32, r33, px, py, pz, qx, qy, qz)
	for _, bone in ipairs(bones) do
		BeatrunIK.MoveBone(ent, bone, r11, r12, r13, r21, r22, r23, r31, r32, r33, px, py, pz, qx, qy, qz)
	end
end

function BeatrunIK.GetBonePos(ent, bone)
	local m = ent:GetBoneMatrix(bone)
	if not m then return end

	local _, _, _, x, _, _, _, y, _, _, _, z = m:Unpack()

	return x, y, z
end

local function IsDescendant(ent, bone, ancestor)
	while bone and bone >= 0 do
		if bone == ancestor then return true end

		bone = ent:GetBoneParent(bone)
	end

	return false
end

-- The bone and everything under it
function BeatrunIK.GetSubtree(ent, bone)
	local bones = {}

	for b = 0, ent:GetBoneCount() - 1 do
		if IsDescendant(ent, b, bone) then
			bones[#bones + 1] = b
		end
	end

	return bones
end

-- Rotation by angle radians around the unit axis ax/ay/az, as a row-major 3x3
function BeatrunIK.AxisAngle(ax, ay, az, angle)
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c

	return t * ax * ax + c, t * ax * ay - s * az, t * ax * az + s * ay,
		t * ax * ay + s * az, t * ay * ay + c, t * ay * az - s * ax,
		t * ax * az - s * ay, t * ay * az + s * ax, t * az * az + c
end

-- Looks up a root -> mid -> end chain and splits the root's subtree into what follows each of the three
-- (twist bones go with their segment, fingers and toes with the end), names past the third end up in chain.extra
function BeatrunIK.GetChain(ent, names)
	local root, mid, tip = ent:LookupBone(names[1]), ent:LookupBone(names[2]), ent:LookupBone(names[3])
	if not root or not mid or not tip then return end

	local rootbones, midbones, endbones = {}, {}, {}

	for b = 0, ent:GetBoneCount() - 1 do
		if IsDescendant(ent, b, tip) then
			endbones[#endbones + 1] = b
		elseif IsDescendant(ent, b, mid) then
			midbones[#midbones + 1] = b
		elseif IsDescendant(ent, b, root) then
			rootbones[#rootbones + 1] = b
		end
	end

	local chain = {
		root = root, mid = mid, tip = tip,
		rootbones = rootbones, midbones = midbones, endbones = endbones,
		extra = {}
	}

	for i = 4, #names do
		chain.extra[i - 3] = ent:LookupBone(names[i])
	end

	return chain
end

-- Bends the chain so its end reaches tx/ty/tz, moving every bone of the subtree along.
-- Returns the new end position, which can be short of the target if it is out of reach
function BeatrunIK.ReachChain(ent, chain, tx, ty, tz, px, py, pz)
	local rx, ry, rz = BeatrunIK.GetBonePos(ent, chain.root)
	local mx, my, mz = BeatrunIK.GetBonePos(ent, chain.mid)
	local ex, ey, ez = BeatrunIK.GetBonePos(ent, chain.tip)

	if not rx or not mx or not ex then return end

	local mx2, my2, mz2, ex2, ey2, ez2 = BeatrunIK.SolveTwoBone(rx, ry, rz, mx, my, mz, ex, ey, ez, tx, ty, tz, px, py, pz)

	local u11, u12, u13, u21, u22, u23, u31, u32, u33 = BeatrunIK.MinArc(mx - rx, my - ry, mz - rz, mx2 - rx, my2 - ry, mz2 - rz)
	local l11, l12, l13, l21, l22, l23, l31, l32, l33 = BeatrunIK.MinArc(ex - mx, ey - my, ez - mz, ex2 - mx2, ey2 - my2, ez2 - mz2)

	BeatrunIK.MoveBones(ent, chain.rootbones, u11, u12, u13, u21, u22, u23, u31, u32, u33, rx, ry, rz, rx, ry, rz)
	BeatrunIK.MoveBones(ent, chain.midbones, l11, l12, l13, l21, l22, l23, l31, l32, l33, mx, my, mz, mx2, my2, mz2)
	BeatrunIK.MoveBones(ent, chain.endbones, 1, 0, 0, 0, 1, 0, 0, 0, 1, ex, ey, ez, ex2, ey2, ez2)

	return ex2, ey2, ez2
end

-- Pose blending, for when an anim moves to a new entity (the other animation set) and would otherwise snap to its pose.
-- Bones are matched by name and kept relative to the pelvis (bone 0 on both sets): that doesn't care about the bone
-- order or hierarchy, or where the entity is drawn (the arm copy is moved around between setups)

local function EntityFrame(ent)
	local m = Matrix()
	m:SetAngles(ent:GetAngles())
	m:SetTranslation(ent:GetPos())

	return m
end

local MINSCALE = 1e-3

-- Rotation and translation lerped from a to b, keeping b's scale. Zero scaled bones (hidden head) just take b
local function BlendMatrix(a, b, w)
	local as, bs = a:GetScale(), b:GetScale()
	if as.x < MINSCALE or bs.x < MINSCALE then return b end

	local fwd = LerpVector(w, a:GetForward():GetNormalized(), b:GetForward():GetNormalized())
	local up = LerpVector(w, a:GetUp():GetNormalized(), b:GetUp():GetNormalized())

	-- Opposite directions, nothing sensible to lerp through
	if fwd:LengthSqr() < 1e-6 or fwd:Cross(up):LengthSqr() < 1e-6 then return b end

	fwd:Normalize()

	local out = Matrix()
	out:SetAngles(fwd:AngleEx(up))
	out:SetTranslation(LerpVector(w, a:GetTranslation(), b:GetTranslation()))
	out:SetScale(bs)

	return out
end

-- The entity's current pose. entityframe also keeps where the pelvis is relative to the entity's position and angles,
-- only use it when the entity is drawn at GetPos/GetAngles (the body anim is, the arm copy isn't)
function BeatrunIK.CapturePose(ent, entityframe)
	if not IsValid(ent) or ent:GetBoneCount() < 1 then return end

	ent:InvalidateBoneCache()
	ent:SetupBones()

	local anchor = ent:GetBoneMatrix(0)
	local inv = anchor and anchor:GetInverse()
	if not inv then return end

	local pose = { bones = {}, params = {} }

	-- Pose parameters are set from code every frame, a fresh entity would show its defaults until that runs again.
	-- GetPoseParameter is normalized (0-1), SetPoseParameter wants the real value
	for i = 0, ent:GetNumPoseParameters() - 1 do
		local name = ent:GetPoseParameterName(i)
		local min, max = ent:GetPoseParameterRange(i)

		pose.params[name] = Lerp(ent:GetPoseParameter(name), min, max)
	end

	for i = 1, ent:GetBoneCount() - 1 do
		local m = ent:GetBoneMatrix(i)

		if m then pose.bones[ent:GetBoneName(i)] = inv * m end
	end

	if entityframe then
		pose.anchor = EntityFrame(ent):GetInverseTR() * anchor
	end

	return pose
end

local function PoseBlend(ent)
	local blend = ent.BeatrunPoseBlend
	if not blend then return end

	local w = (RealTime() - blend.start) / blend.duration

	if w >= 1 then
		ent.BeatrunPoseBlend = nil

		return
	end

	w = w * w * (3 - 2 * w) -- smoothstep

	local anchor = ent:GetBoneMatrix(0)
	local inv = anchor and anchor:GetInverse()
	if not inv then return end

	local pose, names = blend.pose, blend.names
	local newanchor = anchor

	if pose.anchor then
		local frame = EntityFrame(ent)

		newanchor = frame * BlendMatrix(pose.anchor, frame:GetInverseTR() * anchor, w)

		BeatrunIK.SetBoneMatrix(ent, 0, newanchor)
	end

	for i = 1, ent:GetBoneCount() - 1 do
		local from = pose.bones[names[i]]

		-- Without a blended pelvis a bone missing from the pose stays as it is
		if from or pose.anchor then
			local m = ent:GetBoneMatrix(i)

			if m then
				local rel = inv * m

				BeatrunIK.SetBoneMatrix(ent, i, newanchor * (from and BlendMatrix(from, rel, w) or rel))
			end
		end
	end
end

-- Eases ent from pose (CapturePose, usually of the entity it replaces) into its own animation over duration seconds.
-- Runs after the other bone callbacks, so the IK of both poses is blended too
function BeatrunIK.BlendFromPose(ent, pose, duration)
	if not IsValid(ent) or not pose then return end

	-- Right away, not eased: the blend covers the bones, and this is what keeps the new entity from rendering a
	-- frame with every pose parameter at its default before the anim code sets them again
	for name, value in pairs(pose.params) do
		ent:SetPoseParameter(name, value)
	end

	if duration <= 0 then return end

	local names = {}

	for i = 0, ent:GetBoneCount() - 1 do
		names[i] = ent:GetBoneName(i)
	end

	ent.BeatrunPoseBlend = { pose = pose, names = names, start = RealTime(), duration = duration }

	if not ent.BeatrunPoseBlendAdded then
		ent.BeatrunPoseBlendAdded = true

		BeatrunIK.AddBoneCallback(ent, PoseBlend, true)
	end
end
