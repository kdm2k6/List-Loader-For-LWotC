class UIScreenListener_UIPersonnel extends UIScreenListener config(Settings);

var bool RealizationIsComplete;
var int RealizationIncrementer;
var array<int> ListItemsToRealize, ListItemsRealized;
var UIPanel PanelWithOnInitDelegate;
var UIPersonnel PersonnelScreen;

var config bool RealizeSelectedListItemFirst;
var config int NumberOfListItemsToRealizeBeforeVisible, NumberOfVisibleListItems;

event OnInit(UIScreen Screen)
{
	local int SelectedIndex;

	if (!IsAPersonnelScreen(Screen)) { return; }

	PersonnelScreen = UIPersonnel(Screen);
	// KDM : We want to know when the UIPersonnel screen's list selection changes, since this can be a sign
	// that the list has updated via UpdateList.
	//PersonnelScreen.m_kList.OnSelectionChanged = OnPersonnelSelectionChanged;
	PersonnelScreen.m_kList.OnSetSelectedIndex = OnPersonnelSetSelectedIndex;
	// KDM : We want to know when the list's item container has been added, since this can be a sign that
	// the list has been cleared and updated.
	PersonnelScreen.m_kList.OnChildAdded = OnPersonnelChildAdded;

	// KDM : Force a selection update since selection was likely already done with
	// before we hooked up m_kList.OnSelectionChanged.
	RealizationIsComplete = false;
	//`log("RESETTING ARRAY ***************** ONINIT");
	ListItemsRealized.Length = 0;
	SelectedIndex = PersonnelScreen.m_kList.SelectedIndex;
	//PersonnelScreen.m_kList.SetSelectedIndex(SelectedIndex, true);
	PersonnelScreen.m_kList.SetSelectedIndex(SelectedIndex);
}

/*
event OnReceiveFocus(UIScreen Screen)
{
	local int SelectedIndex;

	if (!IsAPersonnelScreen(Screen)) { return; }

	// KDM : Force a selection update since selection was likely already done with
	// before we hooked up m_kList.OnSelectionChanged.
	//RealizationIsComplete = false;
	`log("RESETTING ARRAY ***************** RECEIVEFOCUS");
	//ListItemsRealized.Length = 0;
	//SelectedIndex = PersonnelScreen.m_kList.SelectedIndex;
	//PersonnelScreen.m_kList.SetSelectedIndex(SelectedIndex, true);
}
*/

event OnLoseFocus(UIScreen Screen)
{
	if (!IsAPersonnelScreen(Screen)) { return; }

	// KDM : Kill any OnInitDelegates which are active.
	if (PanelWithOnInitDelegate != none)
	{
		PanelWithOnInitDelegate.ClearOnInitDelegate(RealizeNextItem);
	}

	// KDM : Make sure we stop processing list item realization.
	RealizationIsComplete = true;
}

event OnRemoved(UIScreen Screen)
{
	if (!IsAPersonnelScreen(Screen)) { return; }

	// KDM : Kill any OnInitDelegates which are active.
	if (PanelWithOnInitDelegate != none)
	{
		PanelWithOnInitDelegate.ClearOnInitDelegate(RealizeNextItem);
	}

	if (PersonnelScreen != none && PersonnelScreen.m_kList != none)
	{
		PersonnelScreen.m_kList.OnSetSelectedIndex = none;
		//PersonnelScreen.m_kList.OnSelectionChanged = none;
		PersonnelScreen.m_kList.OnChildAdded = none;
	}
	
	RealizationIsComplete = true;
	ListItemsToRealize.Length = 0;
	PanelWithOnInitDelegate = none;
	PersonnelScreen = none;
}

simulated function bool IsAPersonnelScreen(UIScreen Screen)
{
	return Screen.IsA('UIPersonnel');
}

simulated function OnPersonnelChildAdded(UIPanel ChildPanel)
{
	// KDM : UIPersonnel.UpdateList : 
	// 1.] Removes m_kList's ItemContainer.
	// 2.] Creates a new ItemContainer and adds it to m_kList.
	// 3.] Fills in the ItemContainer with appropriate list items.
	//
	// Therefore, whenever ItemContainer is added to m_kList, we need to get ready to realize all
	// of the newly created list items. If this is not done, RealizationIsComplete is never reset,
	// and the new list items are never realized.
	if (ChildPanel == PersonnelScreen.m_kList.ItemContainer)
	{
		RealizationIsComplete = false;
		//`log("RESETTING ARRAY ***************** CHILD ADDED");
		ListItemsRealized.Length = 0;
	}
}

//simulated function OnPersonnelSelectionChanged(UIList List, int Index)
simulated function OnPersonnelSetSelectedIndex(UIList List, int Index)
{
	// KDM : If the list has no items then don't worry about realizing any list items.
	if (List.ItemCount <= 0)
	{
		return;
	}

	// KDM : If there is no list selection then realize as if we are looking at the top/first item.
	if (Index < 0)
	{
		Index = 0;
	}

	// KDM : We don't want multiple OnInitDelegates active at the same time so kill any older ones.
	if (PanelWithOnInitDelegate != none)
	{
		PanelWithOnInitDelegate.ClearOnInitDelegate(RealizeNextItem);
		PanelWithOnInitDelegate = none;
	}
	
	// KDM : Only attempt to realize items if there are items left to be realized. 
	if (!RealizationIsComplete)
	{
		`log("KDM STARTED THE PROCESS ******************");

		//ShowRealizedListItems();
		SetupListItemPriorities(List, Index);
		RealizeNextItem(none);
	}
}

/*
simulated function ShowRealizedListItems()
{
	local int i;

	if (ListItemsRealized.Length > 0)
	{
		for (i = 0; i < ListItemsRealized.Length; i++)
		{
			PersonnelScreen.m_kList.GetItem(ListItemsRealized[i]).Show();
		}	
	}
}
*/

simulated function SetupListItemPriorities(UIList List, int SelectedIndex)
{
	local bool Descending;
	local int i, ListSize;
	local int LowerLimit, UpperLimit;
	local float ScrollPct;

	RealizationIncrementer = 0;
	ListItemsToRealize.Length = 0;

	ListSize = List.ItemCount;
	Descending = true;

	if (RealizeSelectedListItemFirst)
	{
		// KDM : 'PRIORITY 1' is the selected list item.
		ListItemsToRealize.AddItem(SelectedIndex);
		//`log("ADDING A : " @ SelectedIndex);
	}		

	// KDM : 'PRIORITY 2' are the visible list items.
	ScrollPct = float(SelectedIndex) / float(ListSize - 1);
	
	//`log("KDM ************");
	//`log("SelectedIndex " @ SelectedIndex);
	//`log("ListSize " @ ListSize);
	//`log("ScrollPct " @ ScrollPct);

	// KDM : Here is an explanation of what is being done through an example.
	// If we select list item 30, out of 100, with 10 list items visible at one time, we can see
	// about 3 list items above and 7 list items below.
	LowerLimit = SelectedIndex - FCeil(ScrollPct * float(NumberOfVisibleListItems));
	//`log("LowerLimit " @ LowerLimit);
	if (LowerLimit < 0)
	{
		LowerLimit = 0;
	}

	//`log("LowerLimit " @ LowerLimit);
	
	UpperLimit = SelectedIndex + FCeil((1.0 - ScrollPct) * float(NumberOfVisibleListItems));
	//`log("UpperLimit " @ UpperLimit);
	if (UpperLimit >= ListSize)
	{
		UpperLimit = ListSize - 1;
	}
	//`log("UpperLimit " @ UpperLimit);

	for (i = LowerLimit; i <= UpperLimit; i++)
	{
		// KDM : Don't add the selected list item if it has already been added.
		if (RealizeSelectedListItemFirst && i == SelectedIndex)
		{
			continue;
		}
		ListItemsToRealize.AddItem(i);
		//`log("ADDING B : " @ i);
	}

	//`log("ListItemsToRealize.Length " @ ListItemsToRealize.Length);
	//`log("ListSize " @ ListSize);

	// KDM : 'PRIORITY 3' are the rest of the list items.
	while (ListItemsToRealize.Length < ListSize)
	{
		if (Descending)
		{
			UpperLimit++;
			if (UpperLimit >= ListSize)
			{
				UpperLimit = 0;
			}
			ListItemsToRealize.AddItem(UpperLimit);
			//`log("ADDING C : " @ UpperLimit);
			Descending = false;	
		}
		else
		{
			LowerLimit--;
			if (LowerLimit < 0)
			{
				LowerLimit = ListSize - 1;
			}
			ListItemsToRealize.AddItem(LowerLimit);
			//`log("ADDING C : " @ LowerLimit);
			Descending = true;	
		}
	}
	//`log("ListItemsToRealize.Length " @ ListItemsToRealize.Length);
}

simulated function RealizeNextItem(UIPanel Control)
{
	local int i;
	local UIPersonnel_SoldierListItem_LW_BLR ListItem;

	// KDM : Only enter if there are items left to realize.
	while (RealizationIncrementer < ListItemsToRealize.Length)
	{
		ListItem = UIPersonnel_SoldierListItem_LW_BLR(
			PersonnelScreen.m_kList.GetItem(ListItemsToRealize[RealizationIncrementer]));

		// KDM : If the PsiMarkup image doesn't exist then the list item has not been realized yet.
		if (ListItem != none && ListItem.PsiMarkup == none)
		{
			ListItem.RealizeListItem();
			//`log("RealizationIncrementer is " @ RealizationIncrementer @ ListItemsToRealize[RealizationIncrementer] @ "****" @ ListItemsRealized.Length);
			ListItemsRealized.AddItem(ListItemsToRealize[RealizationIncrementer]);
			ListItem.PsiMarkup.AddOnInitDelegate(RealizeNextItem);
			PanelWithOnInitDelegate = ListItem.PsiMarkup;
			
			RealizationIncrementer++;
			if (RealizationIncrementer >= ListItemsToRealize.Length)
			{
				RealizationIsComplete = true;
			}
			break;
		}
		else
		{
			RealizationIncrementer++;
			if (RealizationIncrementer >= ListItemsToRealize.Length)
			{
				RealizationIsComplete = true;
			}
		}
	}


	if ((ListItemsRealized.Length == NumberOfListItemsToRealizeBeforeVisible) ||
		(RealizationIsComplete && ListItemsRealized.Length < NumberOfListItemsToRealizeBeforeVisible))
	{
		for (i = 0; i < ListItemsRealized.Length; i++)
		{
			//`log("SECTION A : " @ ListItemsRealized[i]);
			PersonnelScreen.m_kList.GetItem(ListItemsRealized[i]).Show();
		}
	}
	else if (ListItemsRealized.Length > NumberOfListItemsToRealizeBeforeVisible)
	{
		//`log("SECTION B : " @ (ListItemsRealized.Length - 1));
		PersonnelScreen.m_kList.GetItem(ListItemsRealized[ListItemsRealized.Length - 1]).Show();
	}
	/*
	KDM TEMP **********
	ListItemsRealized = RealizationIncrementer;
	if (ListItemsRealized == NumberOfListItemsToRealizeBeforeVisible)
	{
		for (i = 0; i < ListItemsRealized; i++)
		{
			PersonnelScreen.m_kList.GetItem(ListItemsToRealize[i]).Show();
		}
	}
	else if (ListItemsRealized > NumberOfListItemsToRealizeBeforeVisible)
	{
		PersonnelScreen.m_kList.GetItem(ListItemsToRealize[ListItemsRealized - 1]).Show();
	}*/
}

defaultProperties
{
	ScreenClass = none;
}
