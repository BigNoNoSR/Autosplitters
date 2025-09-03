/*
Heartworm ASL Script Version 1.1.0
Supports auto-start, auto-reset, load removal, and splitting on picking up key items as well as both phases of the final boss.

Known Issues:
1. Splitting only on Tape Keeper 1 does not work properly.
2. If starting timer manually during a playthrough (e.g. for timing specific parts), will split on every item in inventory for which autosplitting is enabled in settings.
3. At times all elements of the script (notably, auto-start) will fail to activate. This is due to weirdness with how GameManager is loaded. If this happens, try to restart LiveSplit.

Special thanks to the Speedrun Tool Development Discord server, especially rumii and Streetbackguy, for their sage advice and explanations, as well as PlayingLikeAss for his kind help.
*/

state("Heartworm")
{
}

startup
{
    Assembly.Load(File.ReadAllBytes("Components/asl-help")).CreateInstance("Unity");
    Assembly.Load(File.ReadAllBytes("Components/uhara7")).CreateInstance("Main");
    vars.Helper.LoadSceneManager = true;

    settings.Add("HEARTWORM", true, "Heartworm");
    settings.Add("MANSION", true, "Mansion", "HEARTWORM");
    settings.Add("NEIGHBORHOOD", true, "Neighborhood", "HEARTWORM");
    settings.Add("WILDERNESS", true, "Wilderness", "HEARTWORM");
    settings.Add("CLOCKTOWER", true, "Clock Tower", "HEARTWORM");
    settings.Add("FINALE", true, "Finale", "HEARTWORM");
    
    settings.Add("Camera", true, "Camera", "MANSION");
    settings.Add("EmblemPart1", true, "Emblem Left Half", "MANSION");
    settings.Add("EmblemPart2", true, "Emblem Right Half", "MANSION");
    settings.Add("SkeletonKey", true, "Attic Key", "MANSION");

    settings.Add("HouseKey", true, "House Key", "NEIGHBORHOOD");
    settings.Add("BurstMod", true, "Burst Mod", "NEIGHBORHOOD");
    settings.Add("CrowBar", true, "Crowbar", "NEIGHBORHOOD");
    settings.Add("NeighborhoodPage", true, "Neighborhood Page", "NEIGHBORHOOD");

    settings.Add("WatermillKey", true, "Watermill Key", "WILDERNESS");
    settings.Add("BoltCutters", true, "Boltcutters", "WILDERNESS");
    settings.Add("BloodKit", true, "Blood Kit", "WILDERNESS");
    settings.Add("BloodKitUsed", true, "Used Blood Kit", "WILDERNESS");
    settings.Add("HexagonCrank", true, "Hexagon Crank", "WILDERNESS");
    settings.Add("WildernessPage", true, "Wilderness Page", "WILDERNESS");

    // Why is the Delta Emblem called Alpha in code. Why. WHY
    settings.Add("CTEmblemAlpha", true, "Delta Emblem", "CLOCKTOWER");
    settings.Add("CTEmblemGamma", true, "Gamma Emblem", "CLOCKTOWER");
    settings.Add("CTEmblemBeta", true, "Beta Emblem", "CLOCKTOWER");
    settings.Add("CTEmblemOmega", true, "Omega Emblem", "CLOCKTOWER");
    settings.Add("Memento1", true, "Crucifix", "CLOCKTOWER");
    settings.Add("Memento2", true, "Videotape", "CLOCKTOWER");
    settings.Add("Memento3", true, "Work ID", "CLOCKTOWER");
    settings.Add("Memento4", true, "Eulogy", "CLOCKTOWER");
    
    settings.Add("ClockTowerPage", true, "Clock Tower Page", "FINALE");
    settings.Add("CathedralKey", true, "Ancient Key", "FINALE");
    settings.Add("TapeKeeper1", true, "Tape Keeper Phase 1", "FINALE");
    settings.Add("TapeKeeper2", true, "Tape Keeper Phase 2", "FINALE");
}

init
{
    Thread.Sleep(5000); // Very dumb and bad hack to avoid uninitialized GameManager crashing the whole thing
    vars.ItemsCollected = new HashSet<string>();
    vars.NewItem = ""; // Assume we only need to split on one new item at a time
    vars.TapeKeeperPhaseStarted = false;
    vars.TapeKeeperDeathCount = 0; // Tape Keeper's HP gets reset to 60 at the start of each phase

    vars.Phase = 0;
    if (settings["TapeKeeper1"])
    {
        vars.Phase = 1;
    }
    else if (settings["TapeKeeper2"])
    {
        vars.Phase = 2;
    }

    vars.Helper.TryLoad = (Func<dynamic, bool>)(mono =>
    {
        var gmClass = mono.GetClass("Assembly-CSharp", 0x0200008C, 0);
        vars.Helper["ItemList"] = mono.MakeList<IntPtr>(gmClass, "instance", "player", "inventory", "itemList");
        vars.Helper["Loading"] = mono.Make<bool>(gmClass, "instance", "loadingScene");

        var Jit = vars.Uhara.CreateTool("Unity", "DotNet", "JitSave");
        var GameManager = Jit.AddInst("TapeKeeperBossController");
        Jit.ProcessQueue();
        vars.Helper["TapeKeeperHealth"] = vars.Helper.Make<int>(GameManager, 0x170);
        
        return true;
    });
}

onStart
{
    vars.ItemsCollected.Clear();
    vars.NewItem = "";
    vars.TapeKeeperPhaseStarted = false;
    vars.TapeKeeperDeathCount = 0;
}

update
{
    current.activeScene = vars.Helper.Scenes.Active.Name ?? current.activeScene;
    foreach (IntPtr item in current.ItemList)
    {
        // Localization-independent item names have the format Items/<UniqueIdentifier>/Name
        String itemLongName = new DeepPointer(item + 0x10, 0x20, 0x14).DerefString(game, ReadStringType.UTF16, 50);
        String itemShorterName = itemLongName.Substring(itemLongName.IndexOf('/') + 1);
        String itemName = itemShorterName.Substring(0, itemShorterName.IndexOf('/'));
        if (!(vars.ItemsCollected.Contains(itemName)))
        {
            vars.ItemsCollected.Add(itemName);
            vars.NewItem = itemName;
            break; 
        }
    }

    if (!vars.TapeKeeperPhaseStarted)
    {
        if (current.TapeKeeperHealth == 60)
        {
            vars.TapeKeeperPhaseStarted = true;
        }
    }
    if (vars.TapeKeeperPhaseStarted)
    {
        if (current.TapeKeeperHealth == 0)
        {
            vars.TapeKeeperDeathCount++;
            vars.TapeKeeperPhaseStarted = false;
        }
    }

}

isLoading
{
    return current.Loading;
}

start
{
    return current.activeScene == "cut_Intro_Samtalking";
}

reset
{
    return current.activeScene == "MainMenu";
}

split
{
    if (vars.Phase > 0)
    {
        if (vars.TapeKeeperDeathCount == vars.Phase)
        {
            vars.Phase++;
            return true;
        }
    }

    bool doSplit = false;
    if (settings.ContainsKey(vars.NewItem) && settings[vars.NewItem])
    {
        doSplit = true;
    }
    vars.NewItem = "";
    return doSplit;
}
