#pragma once

#include "CoreMinimal.h"
#include "Engine/DataTable.h"
#include "OOTDialogueTypes.generated.h"

/** One spoken or narrated line. Mirrors the prototype format "NAME (TAG): text || subtitle". */
USTRUCT(BlueprintType)
struct OUTOFTOWN_API FOOTDialogueLine : public FTableRowBase
{
	GENERATED_BODY()

	/** Scene this line belongs to, e.g. "e1_call". */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Dialogue")
	FName SceneId;

	/** Order within the scene, starting at 0. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Dialogue")
	int32 Order = 0;

	/** Speaker id, e.g. "NILA". Empty for narration. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Dialogue")
	FName Speaker;

	/** How the line is heard: radio, phone, voicemail, on air, tape... Empty when spoken in person. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Dialogue")
	FName Channel;

	/** The spoken text (Tanglish for family scenes). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Dialogue", meta = (MultiLine = true))
	FText Text;

	/** English subtitle. Always shown; when empty, Text is shown as the subtitle. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Dialogue", meta = (MultiLine = true))
	FText Subtitle;

	/** True when the line is narration or a stage direction rather than speech. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Dialogue")
	bool bIsNarration = false;
};

/** A choice offered to the player at the end of a scene. */
USTRUCT(BlueprintType)
struct OUTOFTOWN_API FOOTChoice : public FTableRowBase
{
	GENERATED_BODY()

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Choice")
	FName SceneId;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Choice")
	FText Label;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Choice")
	FText SubLabel;

	/** Target scene when the choice is taken. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Choice")
	FName TargetScene;

	/** Flags that must all be set for the choice to be available. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Choice")
	TArray<FName> RequiredFlags;

	/** Clues that must all be held for the choice to be available. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Choice")
	TArray<FName> RequiredClues;

	/** Shown when the choice is locked. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Choice")
	FText LockedReason;

	/** Seconds for a timed choice; 0 when untimed. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Choice")
	float TimerSeconds = 0.f;
};
