using UnrealBuildTool;
using System.Collections.Generic;

public class OutOfTownEditorTarget : TargetRules
{
	public OutOfTownEditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.V5;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.Add("OutOfTown");
	}
}
