class UIPersonnel_SoldierListItem_LW_BLR extends UIPersonnel_SoldierListItem_LW;

enum DisabledStatusEnum
{
	Undefined,
	Disabled,
	NotDisabled,
};

var DisabledStatusEnum DisabledStatusUponInitialization;
var string DisabledTooltipText;

simulated function UIButton SetDisabled(bool Disabled, optional string TooltipText)
{
	// KDM : SetDisabled can be called before the list item and all of its children have been
	// initialized. If this does occur, save the information for after initialization.
	if (PsiMarkup != none)
	{
		super.SetDisabled(Disabled, TooltipText);
	}
	else
	{
		if (Disabled)
		{
			DisabledStatusUponInitialization = Disabled;
		}
		else
		{
			DisabledStatusUponInitialization = NotDisabled;
		}

		DisabledTooltipText = TooltipText;
	}
	
	return self;
}

simulated function InitListItem(StateObjectReference initUnitRef)
{
	UnitRef = initUnitRef;
	InitPanel();

	// KDM : We have to spawn and initialize the BondIcon here or else it never updates properly.
	// After a lot of thought and frustration, I think I now understand why :
	// - UIPersonnel_SoldierListItem has a libID of 'SoldierListItem'; consequently, it connects to 'SoldierListItem' 
	// in gfxSoldierList.upk. Now, within SoldierListItem.onLoad we find the statement 
	// this.BondIcon = this.UnitBondIcon; it just so happens that UnitBondIcon is the movie clip name
	// for BondIcon within UIPersonnel_SoldierListItem. 
	// - So, upon loading/initialization, Flash connects its BondIcon variable to Unreal's BondIcon variable, 
	// via movie clip name, and everything works as planned. The problem arises when Unreal's BondIcon is not 
	// spawned and initialized within InitListItem. In this case, Flash tries to 'connect' with Unreal's BondIcon; 
	// however, Unreal's BondIcon doesn't exist. As a result, Flash's BondIcon 'connects' to nothing and stays
	// forever in a 'dormant' state.
	InitBondIcon();
	
	Hide();
}

simulated function InitBondIcon()
{
	if (BondIcon == none)
	{
		BondIcon = Spawn(class'UIBondIcon', self);
		BondIcon.bAnimateOnInit = false;
		if (`ISCONTROLLERACTIVE)
		{
			BondIcon.bIsNavigable = false;
		}
		BondIcon.InitBondIcon('UnitBondIcon');
	}
}

simulated function RealizeListItem()
{
	UpdateData();

	PsiMarkup = Spawn(class'UIImage', self);
	PsiMarkup.bAnimateOnInit = false;
	PsiMarkup.InitImage('PsiPromote', class'UIUtilities_Image'.const.PsiMarkupIcon);
	PsiMarkup.Hide();

	// KDM : Now that the list item has been initialized, set its disabled status if need be.
	if (DisabledStatusUponInitialization == Disabled)
	{
		SetDisabled(true, DisabledTooltipText);
	}
	else if (DisabledStatusUponInitialization == NotDisabled)
	{
		SetDisabled(false, DisabledTooltipText);
	}

	// KDM : A list item can receive focus before all of its children have been initialized, resulting
	// in children who are in the 'wrong state'. What I actually noticed were incorrect class and status
	// text colours for initially selected list items.
	if (bIsFocused)
	{
		bIsFocused = false;
		super(UIPersonnel_SoldierListItem).OnReceiveFocus();
	}
}

simulated function UpdateData()
{
	local int BondLevel, iTimeNum; 
	local string UnitLoc, status, statusTimeLabel, statusTimeValue, mentalStatus, flagIcon;	
	local SoldierBond BondData;
	local StateObjectReference BondmateRef;
	local X2SoldierClassTemplate SoldierClass;
	local XComGameState_ResistanceFaction FactionState;
	local XComGameState_Unit Bondmate, Unit;
	
	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));

	SoldierClass = Unit.GetSoldierClassTemplate();
	FactionState = Unit.GetResistanceFaction();

	class'UIUtilities_Strategy'.static.GetPersonnelStatusSeparate(Unit, status, statusTimeLabel, statusTimeValue);
	mentalStatus = "";

	if (ShouldDisplayMentalStatus(Unit))
	{
		Unit.GetMentalStateStringsSeparate(mentalStatus, statusTimeLabel, iTimeNum);
		statusTimeLabel = class'UIUtilities_Text'.static.GetColoredText(statusTimeLabel, Unit.GetMentalStateUIState());

		if (iTimeNum == 0)
		{
			statusTimeValue = "";
		}
		else
		{
			statusTimeValue = class'UIUtilities_Text'.static.GetColoredText(string(iTimeNum), Unit.GetMentalStateUIState());
		}
	}

	if (statusTimeValue == "")
	{
		statusTimeValue = "---";
	}

	flagIcon = Unit.GetCountryTemplate().FlagImage;

	if (class'UIUtilities_Strategy'.static.DisplayLocation(Unit))
	{
		UnitLoc = class'UIUtilities_Strategy'.static.GetPersonnelLocation(Unit);
	}
	else
	{
		UnitLoc = "";
	}

	// KDM : BondIcon was already spawned in InitBondIcon; therefore, it need not be done here.
	
	if (Unit.HasSoldierBond(BondmateRef, BondData))
	{
		Bondmate = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(BondmateRef.ObjectID));
		BondLevel = BondData.BondLevel;

		// KDM : BondIcon was already initialized in InitBondIcon; however, we now need to set its
		// bond level with the appropriate information. Note that the 4th parameter sent into
		// InitBondIcon is never used, so it need not be worried about.
		BondIcon.SetBondLevel(BondData.BondLevel);
		
		BondIcon.Show();
		SetTooltipText(Repl(BondmateTooltip, "%SOLDIERNAME", Caps(Bondmate.GetName(eNameType_RankFull))));
		Movie.Pres.m_kTooltipMgr.TextTooltip.SetUsePartialPath(CachedTooltipID, true);
	}
	else if (Unit.ShowBondAvailableIcon(BondmateRef, BondData))
	{
		BondLevel = BondData.BondLevel;
		
		// KDM : BondIcon was already initialized in InitBondIcon; however, we now need to set its
		// bond level with the appropriate information.
		BondIcon.SetBondLevel(BondData.BondLevel);

		BondIcon.Show();
		BondIcon.AnimateCohesion(true);
		SetTooltipText(class'XComHQPresentationLayer'.default.m_strBannerBondAvailable);
		Movie.Pres.m_kTooltipMgr.TextTooltip.SetUsePartialPath(CachedTooltipID, true);
	}
	else
	{
		// KDM : BondIcon was already initialized in InitBondIcon; therefore, it need not be done here.

		BondIcon.Hide();
		BondLevel = -1; 
	}

	AS_UpdateDataSoldier(Caps(Unit.GetName(eNameType_Full)),
		Caps(Unit.GetName(eNameType_Nick)),
		Caps(Unit.GetSoldierShortRankName()),
		Unit.GetSoldierRankIcon(),
		Caps(SoldierClass != None ? SoldierClass.DisplayName : ""),
		Unit.GetSoldierClassIcon(),
		status,
		statusTimeValue $"\n" $ Class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(Class'UIUtilities_Text'.static.GetSizedText( statusTimeLabel, 12)),
		UnitLoc,
		flagIcon,
		false,
		Unit.ShowPromoteIcon(),
		Unit.IsPsiOperative() && class'Utilities_PP_LW'.static.CanRankUpPsiSoldier(Unit) && !Unit.IsPsiTraining() && !Unit.IsPsiAbilityTraining(),
		mentalStatus,
		BondLevel);

	// KDM : Flash's SoldierListItem.UpdateData, called via AS_UpdateDataSoldier, is nice enough to set
	// BondIcon._visible to true regardless of the BondLevel. This means a soldier who has no bonds
	// will still have their bond icon shown despite it being hidden just prior. The other 'BIG' problem
	// is that Unreal thinks the BondIcon is hidden because Flash changed visibility values 'behind its back'.
	// Therefore we can't do a simple Hide; we need to modify bIsVisible before calling Hide for it to
	// apply properly.
	if (BondLevel == -1)
	{	
		BondIcon.bIsVisible = true;
		BondIcon.Hide();
	}
	
	AddAdditionalItems(self);

	AS_SetFactionIcon(FactionState.GetFactionIcon());
}

defaultproperties
{
	DisabledStatusUponInitialization = Undefined;
	DisabledTooltipText = "";
}
