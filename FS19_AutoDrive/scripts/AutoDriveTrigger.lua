function AutoDrive:getAllTriggers()    
	AutoDrive.Triggers = {};
	AutoDrive.Triggers.tipTriggers = {};
    AutoDrive.Triggers.siloTriggers = {};
    AutoDrive.Triggers.tipTriggerCount = 0;
    AutoDrive.Triggers.loadTriggerCount = 0;

    --print("AutoDrive looking for triggers");
    
    for _,ownedItem in pairs(g_currentMission.ownedItems) do
        if ownedItem.storeItem ~= nil then
            if ownedItem.storeItem.categoryName == "SILOS" then
                --DebugUtil.printTableRecursively(ownedItem, ":", 0, 3);
                local trigger = {}
                for __,item in pairs(ownedItem.items) do
                    if item.unloadingStation ~= nil then
                        for _,unloadTrigger in pairs(item.unloadingStation.unloadTriggers) do
                            --DebugUtil.printTableRecursively(unloadTrigger, ":", 0, 3);
                            local triggerId = unloadTrigger.exactFillRootNode;
                            trigger = {
                                        triggerId = triggerId;
                                        acceptedFillTypes = item.storages[1].fillTypes;
                                        capacity = item.storages[1].capacityPerFillType;
                                        fillLevels = item.storages[1].fillLevels;
                            
                                    }
                            --print("AutoDrive - found silo unloading trigger: " .. ownedItem.storeItem.categoryName .. " with capacity: " .. trigger.capacity);   
                            
                            AutoDrive.Triggers.tipTriggerCount = AutoDrive.Triggers.tipTriggerCount + 1;
                            AutoDrive.Triggers.tipTriggers[AutoDrive.Triggers.tipTriggerCount] = unloadTrigger;
                        end
                    end;
                    
                    if item.loadingStation ~= nil then
                        for _,loadTrigger in pairs (item.loadingStation.loadTriggers) do
                            local triggerId = loadTrigger.triggerNode;
                            --print("AutoDrive - found silo loading trigger: " .. ownedItem.storeItem.categoryName);   
                            
                            AutoDrive.Triggers.loadTriggerCount = AutoDrive.Triggers.loadTriggerCount + 1;
                            AutoDrive.Triggers.siloTriggers[AutoDrive.Triggers.loadTriggerCount] = loadTrigger;
                        end
                        
                    end
                end;
            end;
        --print("Category: " .. trigger.storeItem.categoryName);    
        end;
    --DebugUtil.printTableRecursively(trigger, ":", 0, 2);
    end;

    if g_currentMission.placeables ~= nil then
		local counter = 0
		for placeableIndex, placeable in pairs(g_currentMission.placeables) do
            if placeable.sellingStation ~= nil then
                local trigger = {}
                for _,unloadTrigger in pairs(placeable.sellingStation.unloadTriggers) do
                    local triggerId = unloadTrigger.exactFillRootNode;
                    trigger = {
                                triggerId = triggerId;
                                acceptedFillTypes = placeable.sellingStation.acceptedFillTypes;
                                                
                            }

                    --print("AutoDrive - found selling unloading trigger: " .. placeable.sellingStation.stationName);   
                
                    AutoDrive.Triggers.tipTriggerCount = AutoDrive.Triggers.tipTriggerCount + 1;
                    AutoDrive.Triggers.tipTriggers[AutoDrive.Triggers.tipTriggerCount] = unloadTrigger;
                end
            end

            if placeable.unloadingStation ~= nil then
				local trigger = {}
				for _,unloadTrigger in pairs(placeable.unloadingStation.unloadTriggers) do
					local triggerId = unloadTrigger.exactFillRootNode;
					trigger = {
								triggerId = triggerId;
								acceptedFillTypes = placeable.storages[1].fillTypes;
								capacity = placeable.storages[1].capacityPerFillType;
								fillLevels = placeable.storages[1].fillLevels;
					
                            }                
                    AutoDrive.Triggers.tipTriggerCount = AutoDrive.Triggers.tipTriggerCount + 1;
                    AutoDrive.Triggers.tipTriggers[AutoDrive.Triggers.tipTriggerCount] = unloadTrigger;
				end
            end
            
            if placeable.modulesById ~= nil then
				for i=1,#placeable.modulesById do
                    local myModule = placeable.modulesById[i]
                    --DebugUtil.printTableRecursively(myModule,":",0,1);
					if myModule.unloadPlace ~= nil then
                        local triggerId = myModule.unloadPlace.target.unloadPlace.exactFillRootNode;
                        local trigger = {	
                                            triggerId = triggerId;
                                            acceptedFillTypes = myModule.unloadPlace.fillTypes;
                                        }
                        AutoDrive.Triggers.tipTriggerCount = AutoDrive.Triggers.tipTriggerCount + 1;
                        AutoDrive.Triggers.tipTriggers[AutoDrive.Triggers.tipTriggerCount] = myModule.unloadPlace;			
					end
										
					if myModule.feedingTrough ~= nil then
						local triggerId = myModule.feedingTrough.target.feedingTrough.exactFillRootNode;
						local trigger = {	
											triggerId = triggerId;
											acceptedFillTypes = myModule.feedingTrough.fillTypes;
										}
                        AutoDrive.Triggers.tipTriggerCount = AutoDrive.Triggers.tipTriggerCount + 1;
                        AutoDrive.Triggers.tipTriggers[AutoDrive.Triggers.tipTriggerCount] = myModule.feedingTrough;	
                    end
                    
                    if myModule.loadPlace ~= nil then                      
                        AutoDrive.Triggers.loadTriggerCount = AutoDrive.Triggers.loadTriggerCount + 1;
                        AutoDrive.Triggers.siloTriggers[AutoDrive.Triggers.loadTriggerCount] =  myModule.loadPlace;            
                    end
				end
			end		
			
			if placeable.buyingStation ~= nil then
				for _,loadTrigger in pairs (placeable.buyingStation.loadTriggers) do
					local triggerId = loadTrigger.triggerNode;
                    AutoDrive.Triggers.loadTriggerCount = AutoDrive.Triggers.loadTriggerCount + 1;
                    AutoDrive.Triggers.siloTriggers[AutoDrive.Triggers.loadTriggerCount] = loadTrigger;
				end
            end
            
            if placeable.loadingStation ~= nil then
                for _,loadTrigger in pairs (placeable.loadingStation.loadTriggers) do
                    local triggerId = loadTrigger.triggerNode; 
                    
                    AutoDrive.Triggers.loadTriggerCount = AutoDrive.Triggers.loadTriggerCount + 1;
                    AutoDrive.Triggers.siloTriggers[AutoDrive.Triggers.loadTriggerCount] = loadTrigger;
                end                
            end
        end;
    end;

    if g_currentMission.nodeToObject ~= nil then
		for _,object in pairs (g_currentMission.nodeToObject) do
            if object.triggerNode ~= nil  then
                AutoDrive.Triggers.loadTriggerCount = AutoDrive.Triggers.loadTriggerCount + 1;
                AutoDrive.Triggers.siloTriggers[AutoDrive.Triggers.loadTriggerCount] = object;
			end
		end			
	end
            
end;