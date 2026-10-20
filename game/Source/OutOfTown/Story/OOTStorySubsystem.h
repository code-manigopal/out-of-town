#pragma once

#include "CoreMinimal.h"
#include "Subsystems/GameInstanceSubsystem.h"
#include "OOTStorySubsystem.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOOTOnClueAdded, FName, ClueId);
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FOOTOnDangerChanged, int32, NewDanger);

/**
 * Holds the story state for the current part: flags, trust per character, danger (0-5),
 * clues and proof, and (Part 2) Nila's health. Mirrors the browser prototype's state model.
 */
UCLASS()
class OUTOFTOWN_API UOOTStorySubsystem : public UGameInstanceSubsystem
{
	GENERATED_BODY()

public:
	/** Clears all state for a new playthrough of a part ("p1" or "p2"). */
	UFUNCTION(BlueprintCallable, Category = "Story")
	void StartPart(FName PartId);

	UFUNCTION(BlueprintPure, Category = "Story")
	FName GetPart() const { return CurrentPart; }

	// Flags
	UFUNCTION(BlueprintCallable, Category = "Story|Flags")
	void SetFlag(FName Flag, bool bValue = true);

	UFUNCTION(BlueprintPure, Category = "Story|Flags")
	bool HasFlag(FName Flag) const;

	// Trust (-3 to 3)
	UFUNCTION(BlueprintCallable, Category = "Story|Trust")
	void AddTrust(FName Character, int32 Delta);

	UFUNCTION(BlueprintPure, Category = "Story|Trust")
	int32 GetTrust(FName Character) const;

	// Danger (0 to 5)
	UFUNCTION(BlueprintCallable, Category = "Story|Danger")
	void AddDanger(int32 Delta);

	UFUNCTION(BlueprintPure, Category = "Story|Danger")
	int32 GetDanger() const { return Danger; }

	// Clues and proof
	UFUNCTION(BlueprintCallable, Category = "Story|Clues")
	bool AddClue(FName ClueId);

	UFUNCTION(BlueprintPure, Category = "Story|Clues")
	bool HasClue(FName ClueId) const { return Clues.Contains(ClueId); }

	UFUNCTION(BlueprintPure, Category = "Story|Clues")
	const TArray<FName>& GetClues() const { return Clues; }

	// Nila's health (Part 2 story clock, 0 to 100)
	UFUNCTION(BlueprintCallable, Category = "Story|Nila")
	void SetNilaHealth(int32 Value);

	UFUNCTION(BlueprintPure, Category = "Story|Nila")
	int32 GetNilaHealth() const { return NilaHealth; }

	UPROPERTY(BlueprintAssignable, Category = "Story")
	FOOTOnClueAdded OnClueAdded;

	UPROPERTY(BlueprintAssignable, Category = "Story")
	FOOTOnDangerChanged OnDangerChanged;

private:
	UPROPERTY()
	FName CurrentPart;

	UPROPERTY()
	TSet<FName> Flags;

	UPROPERTY()
	TMap<FName, int32> Trust;

	UPROPERTY()
	int32 Danger = 0;

	UPROPERTY()
	TArray<FName> Clues;

	UPROPERTY()
	int32 NilaHealth = 100;
};
