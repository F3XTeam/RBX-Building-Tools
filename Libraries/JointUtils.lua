--!strict

type DisabledJointSnapshot = {
	disabledJoints: {JointInstance},
	initialPart0CFrame: {[JointInstance]: CFrame},
	initialPart1CFrame: {[JointInstance]: CFrame},
	anchoredParts: {BasePart},
}

local JointUtils = {}

function JointUtils.RestoreJoints(jointSnapshot: DisabledJointSnapshot)
	for _, joint in jointSnapshot.disabledJoints do
        if not (joint.Part0 and joint.Part1) then
            continue
        end

		local initialOffset = jointSnapshot.initialPart0CFrame[joint]:ToObjectSpace(jointSnapshot.initialPart1CFrame[joint])
		local newOffset = joint.Part0.CFrame:ToObjectSpace(joint.Part1.CFrame)
		local didJointChange = (initialOffset ~= newOffset)
		if didJointChange then
			local didPart0Change = joint.Part0.CFrame ~= jointSnapshot.initialPart0CFrame[joint]
			local didPart1Change = joint.Part1.CFrame ~= jointSnapshot.initialPart1CFrame[joint]
			if didPart0Change then
				joint.C0 = joint.Part0.CFrame:ToObjectSpace(joint.Part1.CFrame:ToWorldSpace(joint.C1))
			end
			if didPart1Change then
				joint.C1 = joint.Part1.CFrame:ToObjectSpace(joint.Part0.CFrame:ToWorldSpace(joint.C0))
			end
		end
		joint.Enabled = true
	end
	for _, part in jointSnapshot.anchoredParts do
		part.Anchored = false
	end
end

function JointUtils.PreserveJoints(part: BasePart): DisabledJointSnapshot
	local initialPart0CFrame: {[JointInstance]: CFrame} = {}
	local initialPart1CFrame: {[JointInstance]: CFrame} = {}
	local disabledJoints: {JointInstance} = {}
	local anchoredParts: {BasePart} = {}

	for _, joint in part:GetJoints() do
		if not (joint:IsA("JointInstance") and joint.Enabled and joint.Part0 and joint.Part1) then
            continue
        end

        joint.Enabled = false
        table.insert(disabledJoints, joint)
        initialPart0CFrame[joint] = joint.Part0.CFrame
        initialPart1CFrame[joint] = joint.Part1.CFrame

        if not joint.Part0.Anchored then
            table.insert(anchoredParts, joint.Part0)
            joint.Part0.Anchored = true
        end
        if not joint.Part1.Anchored then
            table.insert(anchoredParts, joint.Part1)
            joint.Part1.Anchored = true
        end
	end

	return {
		disabledJoints = disabledJoints,
		initialPart0CFrame = initialPart0CFrame,
		initialPart1CFrame = initialPart1CFrame,
		anchoredParts = anchoredParts,
	}
end

return JointUtils