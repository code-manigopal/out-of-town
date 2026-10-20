#include "Story/OOTStorySubsystem.h"
#include "OutOfTown.h"

void UOOTStorySubsystem::StartPart(FName PartId)
{
	CurrentPart = PartId;
	Flags.Reset();
	Trust.Reset();
	Clues.Reset();
	Danger = 0;
	NilaHealth = 100;
	UE_LOG(LogOutOfTown, Log, TEXT("Story: started part %s"), *PartId.ToString());
}

void UOOTStorySubsystem::SetFlag(FName Flag, bool bValue)
{
	if (bValue)
	{
		Flags.Add(Flag);
	}
	else
	{
		Flags.Remove(Flag);
	}
}

bool UOOTStorySubsystem::HasFlag(FName Flag) const
{
	return Flags.Contains(Flag);
}

void UOOTStorySubsystem::AddTrust(FName Character, int32 Delta)
{
	int32& Value = Trust.FindOrAdd(Character);
	Value = FMath::Clamp(Value + Delta, -3, 3);
}

int32 UOOTStorySubsystem::GetTrust(FName Character) const
{
	const int32* Value = Trust.Find(Character);
	return Value ? *Value : 0;
}

void UOOTStorySubsystem::AddDanger(int32 Delta)
{
	const int32 Old = Danger;
	Danger = FMath::Clamp(Danger + Delta, 0, 5);
	if (Danger != Old)
	{
		OnDangerChanged.Broadcast(Danger);
	}
}

bool UOOTStorySubsystem::AddClue(FName ClueId)
{
	if (Clues.Contains(ClueId))
	{
		return false;
	}
	Clues.Add(ClueId);
	OnClueAdded.Broadcast(ClueId);
	return true;
}

void UOOTStorySubsystem::SetNilaHealth(int32 Value)
{
	NilaHealth = FMath::Clamp(Value, 0, 100);
}
