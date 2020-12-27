class UIScreenListener_UIPersonnel extends UIScreenListener config(Settings);

var bool RealizationIsComplete;
var int RealizationIncrementer;
// KDM : Whenever list item selection changes, assuming there are list items left to realize, we prioritize 
// the order with which to realize list items, store it in ListItemsToRealize, then begin the realization process. 
var array<int> ListItemsToRealize;
// KDM : It is important to note that list item selection and, consequently, ListItemsToRealize can change while 
// we are 'in the process' of realizing list items. ListItemsRealized is used to keep track of which
// list items have been realized, independent of selection changes/interruptions.
var array<int> ListItemsRealized;
var UIPanel PanelWithOnInitDelegate;
var UIPersonnel PersonnelScreen;

var config bool RealizeSelectedListItemFirst;
var config int NumberOfListItemsToRealizeBeforeVisible, NumberOfVisibleListItems, NumberOfListItemsToRealizePerRefresh;

event OnInit(UIScreen Screen)
{
	local int SelectedIndex;

	if (!IsAPersonnelScreen(Screen)) { return; }

	PersonnelScreen = UIPersonnel(Screen);
	// KDM : We want to know when the UIPersonnel screen's list selection has been set, since this can be a sign
	// that the list has updated via UpdateList. I originally made use of OnSelectionChanged, which only
	// calls its callback function when the selected index actually 'changes'; however, this was never invoked
	// on the Squad Management screen for mouse and keyboard users.
	PersonnelScreen.m_kList.OnSetSelectedIndex = OnPersonnelSetSelectedIndex;
	// KDM : We want to know when the list's item container has been added, since this can be a sign that
	// the list has been cleared and updated.
	PersonnelScreen.m_kList.OnChildAdded = OnPersonnelChildAdded;

	// KDM : Force a list selection update since selection already occurred before we could hooked up 
	// m_kList.OnSetSelectedIndex.
	RealizationIsComplete = false;
	ListItemsRealized.Length = 0;
	SelectedIndex = PersonnelScreen.m_kList.SelectedIndex;
	PersonnelScreen.m_kList.SetSelectedIndex(SelectedIndex);
}

event OnLoseFocus(UIScreen Screen)
{
	if (!IsAPersonnelScreen(Screen)) { return; }

	// KDM : Kill any OnInitDelegates which are active.
	if (PanelWithOnInitDelegate != none)
	{
		PanelWithOnInitDelegate.ClearOnInitDelegate(RealizeNextItem);
	}

	// KDM : Make sure we stop realizing list items.
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
		ListItemsRealized.Length = 0;
	}
}

simulated function OnPersonnelSetSelectedIndex(UIList List, int Index)
{
	// KDM : If the list has no items then don't worry about realizing any list items.
	if (List.ItemCount <= 0)
	{
		return;
	}

	// KDM : If there is no list selection then realize as if we are looking at the first list item.
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
		SetupListItemPriorities(List, Index);
		RealizeNextItem(none);
	}
}

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
	}		

	// KDM : 'PRIORITY 2' are the visible list items.
	ScrollPct = float(SelectedIndex) / float(ListSize - 1);
	
	// KDM : Here is an explanation of what is being done through an example.
	// If we select list item 30, out of 100, with 10 list items visible at one time, we can see
	// about 3 list items above and 7 list items below.
	LowerLimit = SelectedIndex - FCeil(ScrollPct * float(NumberOfVisibleListItems));
	if (LowerLimit < 0)
	{
		LowerLimit = 0;
	}

	UpperLimit = SelectedIndex + FCeil((1.0 - ScrollPct) * float(NumberOfVisibleListItems));
	if (UpperLimit >= ListSize)
	{
		UpperLimit = ListSize - 1;
	}
	
	for (i = LowerLimit; i <= UpperLimit; i++)
	{
		// KDM : Don't add the selected list item if it has already been added.
		if (RealizeSelectedListItemFirst && i == SelectedIndex)
		{
			continue;
		}
		ListItemsToRealize.AddItem(i);
	}

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
			Descending = true;	
		}
	}
}

simulated function RealizeNextItem(UIPanel Control)
{
	// KDM TEMP NumberOfListItemsToRealizePerRefresh
	local int i, RealizedCounter, ListItemsRealizedBefore;
	local UIPersonnel_SoldierListItem_LW_BLR ListItem;

	RealizedCounter = 0;
	ListItemsRealizedBefore = ListItemsRealized.Length;

	// KDM : Only enter if there are items left to realize.
	while (RealizationIncrementer < ListItemsToRealize.Length)
	{
		ListItem = UIPersonnel_SoldierListItem_LW_BLR(
			PersonnelScreen.m_kList.GetItem(ListItemsToRealize[RealizationIncrementer]));

		// KDM : If the PsiMarkup image doesn't exist then the list item has not been realized yet.
		if (ListItem != none && ListItem.PsiMarkup == none)
		{
			ListItem.RealizeListItem();
			ListItemsRealized.AddItem(ListItemsToRealize[RealizationIncrementer]);
			
			RealizationIncrementer++;
			if (RealizationIncrementer >= ListItemsToRealize.Length)
			{
				RealizationIsComplete = true;
				break;
			}

			RealizedCounter++;
			if (RealizedCounter == NumberOfListItemsToRealizePerRefresh)
			{
				ListItem.PsiMarkup.AddOnInitDelegate(RealizeNextItem);
				PanelWithOnInitDelegate = ListItem.PsiMarkup;
				break;
			}
			//break;
		}
		else
		{
			RealizationIncrementer++;
			if (RealizationIncrementer >= ListItemsToRealize.Length)
			{
				RealizationIsComplete = true;
				break;
			}
		}
	}

	if ((ListItemsRealizedBefore < NumberOfListItemsToRealizeBeforeVisible && 
		ListItemsRealized.Length >= NumberOfListItemsToRealizeBeforeVisible) ||
		(RealizationIsComplete && ListItemsRealized.Length < NumberOfListItemsToRealizeBeforeVisible ))
	{
		for (i = 0; i < ListItemsRealized.Length; i++)
		{
			PersonnelScreen.m_kList.GetItem(ListItemsRealized[i]).Show();
		}
	}
	else if (ListItemsRealized.Length > NumberOfListItemsToRealizeBeforeVisible)
	{
		for (i = ListItemsRealizedBefore; i < ListItemsRealized.Length; i++)
		{
			PersonnelScreen.m_kList.GetItem(ListItemsRealized[i]).Show();
		}
		// PersonnelScreen.m_kList.GetItem(ListItemsRealized[ListItemsRealized.Length - 1]).Show();
	}
	/*
	if ((ListItemsRealized.Length == NumberOfListItemsToRealizeBeforeVisible) ||
		(RealizationIsComplete && ListItemsRealized.Length < NumberOfListItemsToRealizeBeforeVisible))
	{
		for (i = 0; i < ListItemsRealized.Length; i++)
		{
			PersonnelScreen.m_kList.GetItem(ListItemsRealized[i]).Show();
		}
	}
	else if (ListItemsRealized.Length > NumberOfListItemsToRealizeBeforeVisible)
	{
		PersonnelScreen.m_kList.GetItem(ListItemsRealized[ListItemsRealized.Length - 1]).Show();
	}*/
}

defaultProperties
{
	ScreenClass = none;
}
