-- SceneAnalysisService runtime observations; JSON for reanalysis.
return [====[
{
  "runtimeCommit": "83486ea",
  "note": "Queries during continuous active soak, not matched cleanup snapshots; aggregate counters include engine state.",
  "samples": {
    "Early": {
      "Client": {
        "at": "2026-10-27T14:05:38Z",
        "phase": "soak-clean-baseline",
        "GetUnparentedInstancesAsync": {
          "Children": [
            {
              "Children": [
                {
                  "Name": "AnimationTrack",
                  "Size": 8
                }
              ],
              "Name": "(unknown)",
              "Size": 8
            },
            {
              "Children": [
                {
                  "Name": "Animation",
                  "Size": 4
                },
                {
                  "Name": "AnimationTrack",
                  "Size": 432
                }
              ],
              "Name": "Players.Player2.PlayerScripts.GoblinHordeClient",
              "Size": 436
            },
            {
              "Children": [
                {
                  "Name": "AnimationTrack",
                  "Size": 4
                }
              ],
              "Name": "ReplicatedStorage.Goblin.GoblinVFX",
              "Size": 4
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.CameraModule.MouseLockController",
              "Size": 1
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.CommonUtils.CharacterUtil",
              "Size": 1
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 2
                },
                {
                  "Name": "UserGameSettings",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.ControlModule",
              "Size": 3
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.ControlModule.AvatarAbilitiesInterface",
              "Size": 1
            },
            {
              "Children": [
                {
                  "Name": "Animation",
                  "Size": 1
                },
                {
                  "Name": "Part",
                  "Size": 3
                }
              ],
              "Name": "StarterPlayer.PlayerModule.ControlModule.ClickToMoveDisplay",
              "Size": 4
            },
            {
              "Children": [
                {
                  "Name": "Animation",
                  "Size": 26
                },
                {
                  "Name": "AnimationTrack",
                  "Size": 1
                },
                {
                  "Name": "Humanoid",
                  "Size": 1
                },
                {
                  "Name": "LocalScript",
                  "Size": 1
                },
                {
                  "Name": "Model",
                  "Size": 1
                },
                {
                  "Name": "NumberValue",
                  "Size": 1
                }
              ],
              "Name": "Workspace.Player2.Animate",
              "Size": 31
            }
          ],
          "Name": "UnparentedInstances",
          "Size": 489
        },
        "GetAudioMemoryAsync": {
          "Children": [
            {
              "AssetId": "rbxassetid://10066921516",
              "Name": "CoreGui.RobloxGui.ShutterSound",
              "Size": 101868
            },
            {
              "Children": [
                {
                  "AssetId": "rbxassetid://112485797063762",
                  "Name": "SoundService.GoblinSFX.LevelUp",
                  "Size": 295684
                },
                {
                  "AssetId": "rbxassetid://118217695193917",
                  "Name": "SoundService.GoblinSFX.Fireball",
                  "Size": 400896
                },
                {
                  "AssetId": "rbxassetid://126202409049252",
                  "Name": "SoundService.GoblinSFX.Hurt",
                  "Size": 50190
                },
                {
                  "AssetId": "rbxassetid://129285831966291",
                  "Name": "SoundService.GoblinSFX.GameOver",
                  "Size": 294000
                },
                {
                  "AssetId": "rbxassetid://134671877618939",
                  "Name": "SoundService.GoblinSFX.GoblinSwing",
                  "Size": 98436
                },
                {
                  "AssetId": "rbxassetid://135315310485417",
                  "Name": "SoundService.GoblinSFX.Slash",
                  "Size": 115200
                },
                {
                  "AssetId": "rbxassetid://139520673393967",
                  "Name": "SoundService.GoblinSFX.Hit",
                  "Size": 64704
                },
                {
                  "AssetId": "rbxassetid://2575934454",
                  "Name": "SoundService.GoblinSFX.Gem",
                  "Size": 34560
                },
                {
                  "AssetId": "rbxassetid://72264591133889",
                  "Name": "SoundService.GoblinSFX.GoblinPop",
                  "Size": 239616
                }
              ],
              "Name": "SoundService.GoblinSFX",
              "Size": 1593286
            },
            {
              "Children": [
                {
                  "AssetId": "rbxasset://sounds/action_falling.ogg",
                  "Name": "Workspace.Player2.HumanoidRootPart.FreeFalling",
                  "Size": 1764000
                },
                {
                  "AssetId": "rbxasset://sounds/action_footsteps_plastic.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Climbing",
                  "Size": 218880
                },
                {
                  "AssetId": "rbxasset://sounds/action_get_up.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.GettingUp",
                  "Size": 50688
                },
                {
                  "AssetId": "rbxasset://sounds/action_jump.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Jumping",
                  "Size": 29952
                },
                {
                  "AssetId": "rbxasset://sounds/action_jump_land.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Landing",
                  "Size": 23040
                },
                {
                  "AssetId": "rbxasset://sounds/action_swim.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Swimming",
                  "Size": 430848
                },
                {
                  "AssetId": "rbxasset://sounds/impact_water.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Splash",
                  "Size": 209664
                }
              ],
              "Name": "Workspace.Player2.HumanoidRootPart",
              "Size": 2727072
            },
            {
              "Owners": [
                {
                  "Name": "CoreGui.RobloxGui.Sounds.VolumeChangeSound",
                  "ClassName": "Sound"
                },
                {
                  "Name": "Workspace.Player2.HumanoidRootPart.Died",
                  "ClassName": "Sound"
                }
              ],
              "AssetId": "rbxasset://sounds/uuhhh.mp3",
              "Name": "rbxasset://sounds/uuhhh.mp3",
              "Size": 14654
            }
          ],
          "Name": "AudioMemory",
          "Size": 4436880
        },
        "GetScriptMemoryAsync": {
          "Children": [
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "Players.Player2.PlayerScripts.RbxCharacterSounds.AtomicBinding",
                      "Size": 14840
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 14840
                },
                {
                  "Children": [
                    {
                      "Name": "Players.Player2.PlayerGui.Freecam.FreecamScript",
                      "Size": 216646
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinHordeClient",
                      "Size": 206384
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinRunUI",
                      "Size": 89233
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.RbxCharacterSounds",
                      "Size": 40912
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinStressHUD",
                      "Size": 32963
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinSFX",
                      "Size": 14325
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinVFXClient",
                      "Size": 9152
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 609615
                }
              ],
              "Name": "Players",
              "Size": 624455
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinVFX",
                      "Size": 69549
                    },
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinConfig",
                      "Size": 41850
                    },
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinAnimData",
                      "Size": 19404
                    },
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinSounds",
                      "Size": 10526
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 141329
                }
              ],
              "Name": "ReplicatedStorage",
              "Size": 141329
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.ClickToMoveController",
                      "Size": 82411
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule",
                      "Size": 61166
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.BaseCamera",
                      "Size": 48356
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.DynamicThumbstick",
                      "Size": 42540
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule",
                      "Size": 38092
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.ClickToMoveDisplay",
                      "Size": 37049
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.AvatarAbilitiesInterface",
                      "Size": 34519
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.Invisicam",
                      "Size": 33542
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.ZoomController.Popper",
                      "Size": 26496
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VRCamera",
                      "Size": 23493
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VRBaseCamera",
                      "Size": 22722
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.CameraUtils",
                      "Size": 21789
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VRVehicleCamera",
                      "Size": 21378
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.ClassicThumbstick",
                      "Size": 17979
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.CameraInput",
                      "Size": 17370
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.OrbitalCamera",
                      "Size": 16124
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.TouchJump",
                      "Size": 15108
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VehicleCamera.VehicleCameraCore",
                      "Size": 13680
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VehicleCamera",
                      "Size": 13079
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.TransparencyController",
                      "Size": 12990
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.Poppercam",
                      "Size": 11779
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.MouseLockController",
                      "Size": 11206
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.ClassicCamera",
                      "Size": 10683
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.CharacterUtil",
                      "Size": 9799
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.ZoomController",
                      "Size": 9096
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.PlayerModuleInternal",
                      "Size": 8709
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule",
                      "Size": 7894
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.CameraWrapper",
                      "Size": 7289
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.LegacyCamera",
                      "Size": 5685
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.VehicleController",
                      "Size": 5484
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.ActionController",
                      "Size": 5275
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.BaseOcclusion",
                      "Size": 5054
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ServerAuthority",
                      "Size": 4887
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VehicleCamera.VehicleCameraConfig",
                      "Size": 4234
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.ConnectionUtil",
                      "Size": 3951
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.CameraToggleStateController",
                      "Size": 3888
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.EventBus",
                      "Size": 3117
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.CameraUI",
                      "Size": 2623
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils",
                      "Size": 2244
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VRCameraTeleportDetector",
                      "Size": 1874
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.FlagUtil",
                      "Size": 1622
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.PlayerModuleEventBus",
                      "Size": 1217
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.VRFirstPersonState",
                      "Size": 941
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 728434
                },
                {
                  "Children": [
                    {
                      "Name": "StarterPlayer.PlayerModule.PlayerScriptsLoader",
                      "Size": 1480
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 1480
                }
              ],
              "Name": "StarterPlayer",
              "Size": 729914
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "Workspace.Player2.Animate",
                      "Size": 125948
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 125948
                }
              ],
              "Name": "Workspace",
              "Size": 125948
            }
          ],
          "Name": "ScriptMemory",
          "Size": 1989989
        }
      },
      "Server": {
        "at": "2026-10-27T14:05:43Z",
        "phase": "soak-clean-baseline",
        "GetUnparentedInstancesAsync": {
          "Children": [
            {
              "Children": [
                {
                  "Name": "AnimationTrack",
                  "Size": 84
                },
                {
                  "Name": "Path",
                  "Size": 4
                }
              ],
              "Name": "ServerScriptService.GoblinAI",
              "Size": 88
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.CommonUtils.PlayerModuleEventBus",
              "Size": 1
            }
          ],
          "Name": "UnparentedInstances",
          "Size": 89
        },
        "GetAudioMemoryAsync": {
          "Children": [],
          "Name": "AudioMemory",
          "Size": 0
        },
        "GetScriptMemoryAsync": {
          "Children": [
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinConfig",
                      "Size": 33384
                    },
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinAnimData",
                      "Size": 19765
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 53149
                }
              ],
              "Name": "ReplicatedStorage",
              "Size": 53149
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "ServerScriptService.GoblinHorde",
                      "Size": 296058
                    },
                    {
                      "Name": "ServerScriptService.GoblinAI",
                      "Size": 79793
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 375851
                }
              ],
              "Name": "ServerScriptService",
              "Size": 375851
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.EventBus",
                      "Size": 3271
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils",
                      "Size": 2244
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.FlagUtil",
                      "Size": 1699
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.PlayerModuleEventBus",
                      "Size": 1375
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 8589
                },
                {
                  "Children": [
                    {
                      "Name": "StarterPlayer.PlayerModule.InputSetup",
                      "Size": 17433
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 17433
                }
              ],
              "Name": "StarterPlayer",
              "Size": 26022
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "Workspace.Player2.Health",
                      "Size": 2563
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 2563
                }
              ],
              "Name": "Workspace",
              "Size": 2563
            }
          ],
          "Name": "ScriptMemory",
          "Size": 595650
        }
      }
    },
    "Middle": {
      "Client": {
        "at": "2026-10-27T14:11:39Z",
        "phase": "soak-360",
        "GetUnparentedInstancesAsync": {
          "Children": [
            {
              "Children": [
                {
                  "Name": "AnimationTrack",
                  "Size": 8
                }
              ],
              "Name": "(unknown)",
              "Size": 8
            },
            {
              "Children": [
                {
                  "Name": "Animation",
                  "Size": 4
                },
                {
                  "Name": "AnimationTrack",
                  "Size": 432
                }
              ],
              "Name": "Players.Player2.PlayerScripts.GoblinHordeClient",
              "Size": 436
            },
            {
              "Children": [
                {
                  "Name": "AnimationTrack",
                  "Size": 4
                }
              ],
              "Name": "ReplicatedStorage.Goblin.GoblinVFX",
              "Size": 4
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.CameraModule.MouseLockController",
              "Size": 1
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.CommonUtils.CharacterUtil",
              "Size": 1
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 2
                },
                {
                  "Name": "UserGameSettings",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.ControlModule",
              "Size": 3
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.ControlModule.AvatarAbilitiesInterface",
              "Size": 1
            },
            {
              "Children": [
                {
                  "Name": "Animation",
                  "Size": 1
                },
                {
                  "Name": "Part",
                  "Size": 3
                }
              ],
              "Name": "StarterPlayer.PlayerModule.ControlModule.ClickToMoveDisplay",
              "Size": 4
            },
            {
              "Children": [
                {
                  "Name": "Animation",
                  "Size": 26
                },
                {
                  "Name": "AnimationTrack",
                  "Size": 1
                },
                {
                  "Name": "Humanoid",
                  "Size": 1
                },
                {
                  "Name": "LocalScript",
                  "Size": 1
                },
                {
                  "Name": "Model",
                  "Size": 1
                },
                {
                  "Name": "NumberValue",
                  "Size": 1
                }
              ],
              "Name": "Workspace.Player2.Animate",
              "Size": 31
            }
          ],
          "Name": "UnparentedInstances",
          "Size": 489
        },
        "GetAudioMemoryAsync": {
          "Children": [
            {
              "AssetId": "rbxassetid://10066921516",
              "Name": "CoreGui.RobloxGui.ShutterSound",
              "Size": 101868
            },
            {
              "Children": [
                {
                  "AssetId": "rbxassetid://112485797063762",
                  "Name": "SoundService.GoblinSFX.LevelUp",
                  "Size": 295684
                },
                {
                  "AssetId": "rbxassetid://118217695193917",
                  "Name": "SoundService.GoblinSFX.Fireball",
                  "Size": 400896
                },
                {
                  "AssetId": "rbxassetid://126202409049252",
                  "Name": "SoundService.GoblinSFX.Hurt",
                  "Size": 50190
                },
                {
                  "AssetId": "rbxassetid://129285831966291",
                  "Name": "SoundService.GoblinSFX.GameOver",
                  "Size": 294000
                },
                {
                  "AssetId": "rbxassetid://134671877618939",
                  "Name": "SoundService.GoblinSFX.GoblinSwing",
                  "Size": 98436
                },
                {
                  "AssetId": "rbxassetid://135315310485417",
                  "Name": "SoundService.GoblinSFX.Slash",
                  "Size": 115200
                },
                {
                  "AssetId": "rbxassetid://139520673393967",
                  "Name": "SoundService.GoblinSFX.Hit",
                  "Size": 64704
                },
                {
                  "AssetId": "rbxassetid://2575934454",
                  "Name": "SoundService.GoblinSFX.Gem",
                  "Size": 34560
                },
                {
                  "AssetId": "rbxassetid://72264591133889",
                  "Name": "SoundService.GoblinSFX.GoblinPop",
                  "Size": 239616
                }
              ],
              "Name": "SoundService.GoblinSFX",
              "Size": 1593286
            },
            {
              "Children": [
                {
                  "AssetId": "rbxasset://sounds/action_falling.ogg",
                  "Name": "Workspace.Player2.HumanoidRootPart.FreeFalling",
                  "Size": 1764000
                },
                {
                  "AssetId": "rbxasset://sounds/action_footsteps_plastic.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Climbing",
                  "Size": 218880
                },
                {
                  "AssetId": "rbxasset://sounds/action_get_up.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.GettingUp",
                  "Size": 50688
                },
                {
                  "AssetId": "rbxasset://sounds/action_jump.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Jumping",
                  "Size": 29952
                },
                {
                  "AssetId": "rbxasset://sounds/action_jump_land.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Landing",
                  "Size": 23040
                },
                {
                  "AssetId": "rbxasset://sounds/action_swim.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Swimming",
                  "Size": 430848
                },
                {
                  "AssetId": "rbxasset://sounds/impact_water.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Splash",
                  "Size": 209664
                }
              ],
              "Name": "Workspace.Player2.HumanoidRootPart",
              "Size": 2727072
            },
            {
              "Owners": [
                {
                  "Name": "CoreGui.RobloxGui.Sounds.VolumeChangeSound",
                  "ClassName": "Sound"
                },
                {
                  "Name": "Workspace.Player2.HumanoidRootPart.Died",
                  "ClassName": "Sound"
                }
              ],
              "AssetId": "rbxasset://sounds/uuhhh.mp3",
              "Name": "rbxasset://sounds/uuhhh.mp3",
              "Size": 14654
            }
          ],
          "Name": "AudioMemory",
          "Size": 4436880
        },
        "GetScriptMemoryAsync": {
          "Children": [
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "Players.Player2.PlayerScripts.RbxCharacterSounds.AtomicBinding",
                      "Size": 14840
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 14840
                },
                {
                  "Children": [
                    {
                      "Name": "Players.Player2.PlayerGui.Freecam.FreecamScript",
                      "Size": 216646
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinHordeClient",
                      "Size": 209948
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinRunUI",
                      "Size": 89157
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.RbxCharacterSounds",
                      "Size": 40912
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinStressHUD",
                      "Size": 32933
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinSFX",
                      "Size": 12453
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinVFXClient",
                      "Size": 9152
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 611201
                }
              ],
              "Name": "Players",
              "Size": 626041
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinVFX",
                      "Size": 69547
                    },
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinConfig",
                      "Size": 41850
                    },
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinAnimData",
                      "Size": 19404
                    },
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinSounds",
                      "Size": 10526
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 141327
                }
              ],
              "Name": "ReplicatedStorage",
              "Size": 141327
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.ClickToMoveController",
                      "Size": 82411
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule",
                      "Size": 61166
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.BaseCamera",
                      "Size": 48356
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.DynamicThumbstick",
                      "Size": 42540
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule",
                      "Size": 38092
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.ClickToMoveDisplay",
                      "Size": 37049
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.AvatarAbilitiesInterface",
                      "Size": 34519
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.Invisicam",
                      "Size": 33542
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.ZoomController.Popper",
                      "Size": 26496
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VRCamera",
                      "Size": 23493
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VRBaseCamera",
                      "Size": 22722
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.CameraUtils",
                      "Size": 21789
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VRVehicleCamera",
                      "Size": 21378
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.ClassicThumbstick",
                      "Size": 17979
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.CameraInput",
                      "Size": 17370
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.OrbitalCamera",
                      "Size": 16124
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.TouchJump",
                      "Size": 15108
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VehicleCamera.VehicleCameraCore",
                      "Size": 13680
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VehicleCamera",
                      "Size": 13079
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.TransparencyController",
                      "Size": 12990
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.Poppercam",
                      "Size": 11779
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.MouseLockController",
                      "Size": 11206
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.ClassicCamera",
                      "Size": 10683
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.CharacterUtil",
                      "Size": 9799
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.ZoomController",
                      "Size": 9096
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.PlayerModuleInternal",
                      "Size": 8709
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule",
                      "Size": 7894
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.CameraWrapper",
                      "Size": 7289
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.LegacyCamera",
                      "Size": 5685
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.VehicleController",
                      "Size": 5484
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.ActionController",
                      "Size": 5275
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.BaseOcclusion",
                      "Size": 5054
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ServerAuthority",
                      "Size": 4887
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VehicleCamera.VehicleCameraConfig",
                      "Size": 4234
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.ConnectionUtil",
                      "Size": 3951
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.CameraToggleStateController",
                      "Size": 3888
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.EventBus",
                      "Size": 3117
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.CameraUI",
                      "Size": 2623
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils",
                      "Size": 2244
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VRCameraTeleportDetector",
                      "Size": 1874
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.FlagUtil",
                      "Size": 1622
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.PlayerModuleEventBus",
                      "Size": 1217
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.VRFirstPersonState",
                      "Size": 941
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 728434
                },
                {
                  "Children": [
                    {
                      "Name": "StarterPlayer.PlayerModule.PlayerScriptsLoader",
                      "Size": 1480
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 1480
                }
              ],
              "Name": "StarterPlayer",
              "Size": 729914
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "Workspace.Player2.Animate",
                      "Size": 125948
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 125948
                }
              ],
              "Name": "Workspace",
              "Size": 125948
            }
          ],
          "Name": "ScriptMemory",
          "Size": 1967469
        }
      },
      "Server": {
        "at": "2026-10-27T14:11:43Z",
        "phase": "soak-360",
        "GetUnparentedInstancesAsync": {
          "Children": [
            {
              "Children": [
                {
                  "Name": "AnimationTrack",
                  "Size": 84
                },
                {
                  "Name": "Path",
                  "Size": 4
                }
              ],
              "Name": "ServerScriptService.GoblinAI",
              "Size": 88
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.CommonUtils.PlayerModuleEventBus",
              "Size": 1
            }
          ],
          "Name": "UnparentedInstances",
          "Size": 89
        },
        "GetAudioMemoryAsync": {
          "Children": [],
          "Name": "AudioMemory",
          "Size": 0
        },
        "GetScriptMemoryAsync": {
          "Children": [
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinConfig",
                      "Size": 33384
                    },
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinAnimData",
                      "Size": 19765
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 53149
                }
              ],
              "Name": "ReplicatedStorage",
              "Size": 53149
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "ServerScriptService.GoblinHorde",
                      "Size": 311227
                    },
                    {
                      "Name": "ServerScriptService.GoblinAI",
                      "Size": 79793
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 391020
                }
              ],
              "Name": "ServerScriptService",
              "Size": 391020
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.EventBus",
                      "Size": 3271
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils",
                      "Size": 2244
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.FlagUtil",
                      "Size": 1699
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.PlayerModuleEventBus",
                      "Size": 1375
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 8589
                },
                {
                  "Children": [
                    {
                      "Name": "StarterPlayer.PlayerModule.InputSetup",
                      "Size": 17433
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 17433
                }
              ],
              "Name": "StarterPlayer",
              "Size": 26022
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "Workspace.Player2.Health",
                      "Size": 2563
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 2563
                }
              ],
              "Name": "Workspace",
              "Size": 2563
            }
          ],
          "Name": "ScriptMemory",
          "Size": 610819
        }
      }
    },
    "Late": {
      "Client": {
        "at": "2026-10-27T14:19:24Z",
        "phase": "soak-840",
        "GetUnparentedInstancesAsync": {
          "Children": [
            {
              "Children": [
                {
                  "Name": "AnimationTrack",
                  "Size": 8
                }
              ],
              "Name": "(unknown)",
              "Size": 8
            },
            {
              "Children": [
                {
                  "Name": "Animation",
                  "Size": 4
                },
                {
                  "Name": "AnimationTrack",
                  "Size": 432
                }
              ],
              "Name": "Players.Player2.PlayerScripts.GoblinHordeClient",
              "Size": 436
            },
            {
              "Children": [
                {
                  "Name": "AnimationTrack",
                  "Size": 4
                }
              ],
              "Name": "ReplicatedStorage.Goblin.GoblinVFX",
              "Size": 4
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.CameraModule.MouseLockController",
              "Size": 1
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.CommonUtils.CharacterUtil",
              "Size": 1
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 2
                },
                {
                  "Name": "UserGameSettings",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.ControlModule",
              "Size": 3
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.ControlModule.AvatarAbilitiesInterface",
              "Size": 1
            },
            {
              "Children": [
                {
                  "Name": "Animation",
                  "Size": 1
                },
                {
                  "Name": "Part",
                  "Size": 3
                }
              ],
              "Name": "StarterPlayer.PlayerModule.ControlModule.ClickToMoveDisplay",
              "Size": 4
            },
            {
              "Children": [
                {
                  "Name": "Animation",
                  "Size": 26
                },
                {
                  "Name": "AnimationTrack",
                  "Size": 1
                },
                {
                  "Name": "Humanoid",
                  "Size": 1
                },
                {
                  "Name": "LocalScript",
                  "Size": 1
                },
                {
                  "Name": "Model",
                  "Size": 1
                },
                {
                  "Name": "NumberValue",
                  "Size": 1
                }
              ],
              "Name": "Workspace.Player2.Animate",
              "Size": 31
            }
          ],
          "Name": "UnparentedInstances",
          "Size": 489
        },
        "GetAudioMemoryAsync": {
          "Children": [
            {
              "AssetId": "rbxassetid://10066921516",
              "Name": "CoreGui.RobloxGui.ShutterSound",
              "Size": 101868
            },
            {
              "Children": [
                {
                  "AssetId": "rbxassetid://112485797063762",
                  "Name": "SoundService.GoblinSFX.LevelUp",
                  "Size": 295684
                },
                {
                  "AssetId": "rbxassetid://118217695193917",
                  "Name": "SoundService.GoblinSFX.Fireball",
                  "Size": 400896
                },
                {
                  "AssetId": "rbxassetid://126202409049252",
                  "Name": "SoundService.GoblinSFX.Hurt",
                  "Size": 50190
                },
                {
                  "AssetId": "rbxassetid://129285831966291",
                  "Name": "SoundService.GoblinSFX.GameOver",
                  "Size": 294000
                },
                {
                  "AssetId": "rbxassetid://134671877618939",
                  "Name": "SoundService.GoblinSFX.GoblinSwing",
                  "Size": 98436
                },
                {
                  "AssetId": "rbxassetid://135315310485417",
                  "Name": "SoundService.GoblinSFX.Slash",
                  "Size": 115200
                },
                {
                  "AssetId": "rbxassetid://139520673393967",
                  "Name": "SoundService.GoblinSFX.Hit",
                  "Size": 64704
                },
                {
                  "AssetId": "rbxassetid://2575934454",
                  "Name": "SoundService.GoblinSFX.Gem",
                  "Size": 34560
                },
                {
                  "AssetId": "rbxassetid://72264591133889",
                  "Name": "SoundService.GoblinSFX.GoblinPop",
                  "Size": 239616
                }
              ],
              "Name": "SoundService.GoblinSFX",
              "Size": 1593286
            },
            {
              "Children": [
                {
                  "AssetId": "rbxasset://sounds/action_falling.ogg",
                  "Name": "Workspace.Player2.HumanoidRootPart.FreeFalling",
                  "Size": 1764000
                },
                {
                  "AssetId": "rbxasset://sounds/action_footsteps_plastic.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Climbing",
                  "Size": 218880
                },
                {
                  "AssetId": "rbxasset://sounds/action_get_up.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.GettingUp",
                  "Size": 50688
                },
                {
                  "AssetId": "rbxasset://sounds/action_jump.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Jumping",
                  "Size": 29952
                },
                {
                  "AssetId": "rbxasset://sounds/action_jump_land.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Landing",
                  "Size": 23040
                },
                {
                  "AssetId": "rbxasset://sounds/action_swim.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Swimming",
                  "Size": 430848
                },
                {
                  "AssetId": "rbxasset://sounds/impact_water.mp3",
                  "Name": "Workspace.Player2.HumanoidRootPart.Splash",
                  "Size": 209664
                }
              ],
              "Name": "Workspace.Player2.HumanoidRootPart",
              "Size": 2727072
            },
            {
              "Owners": [
                {
                  "Name": "CoreGui.RobloxGui.Sounds.VolumeChangeSound",
                  "ClassName": "Sound"
                },
                {
                  "Name": "Workspace.Player2.HumanoidRootPart.Died",
                  "ClassName": "Sound"
                }
              ],
              "AssetId": "rbxasset://sounds/uuhhh.mp3",
              "Name": "rbxasset://sounds/uuhhh.mp3",
              "Size": 14654
            }
          ],
          "Name": "AudioMemory",
          "Size": 4436880
        },
        "GetScriptMemoryAsync": {
          "Children": [
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "Players.Player2.PlayerScripts.RbxCharacterSounds.AtomicBinding",
                      "Size": 14840
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 14840
                },
                {
                  "Children": [
                    {
                      "Name": "Players.Player2.PlayerGui.Freecam.FreecamScript",
                      "Size": 216646
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinHordeClient",
                      "Size": 207250
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinRunUI",
                      "Size": 89185
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.RbxCharacterSounds",
                      "Size": 40912
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinStressHUD",
                      "Size": 32963
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinSFX",
                      "Size": 12453
                    },
                    {
                      "Name": "Players.Player2.PlayerScripts.GoblinVFXClient",
                      "Size": 9200
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 608609
                }
              ],
              "Name": "Players",
              "Size": 623449
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinVFX",
                      "Size": 69547
                    },
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinConfig",
                      "Size": 41850
                    },
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinAnimData",
                      "Size": 19404
                    },
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinSounds",
                      "Size": 10526
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 141327
                }
              ],
              "Name": "ReplicatedStorage",
              "Size": 141327
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.ClickToMoveController",
                      "Size": 82411
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule",
                      "Size": 61166
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.BaseCamera",
                      "Size": 48356
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.DynamicThumbstick",
                      "Size": 42540
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule",
                      "Size": 38092
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.ClickToMoveDisplay",
                      "Size": 37049
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.AvatarAbilitiesInterface",
                      "Size": 34519
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.Invisicam",
                      "Size": 33542
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.ZoomController.Popper",
                      "Size": 26496
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VRCamera",
                      "Size": 23493
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VRBaseCamera",
                      "Size": 22722
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.CameraUtils",
                      "Size": 21789
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VRVehicleCamera",
                      "Size": 21378
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.ClassicThumbstick",
                      "Size": 17979
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.CameraInput",
                      "Size": 17370
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.OrbitalCamera",
                      "Size": 16124
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.TouchJump",
                      "Size": 15108
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VehicleCamera.VehicleCameraCore",
                      "Size": 13680
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VehicleCamera",
                      "Size": 13079
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.TransparencyController",
                      "Size": 12990
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.Poppercam",
                      "Size": 11779
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.MouseLockController",
                      "Size": 11206
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.ClassicCamera",
                      "Size": 10683
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.CharacterUtil",
                      "Size": 9799
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.ZoomController",
                      "Size": 9096
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.PlayerModuleInternal",
                      "Size": 8709
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule",
                      "Size": 7894
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.CameraWrapper",
                      "Size": 7289
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.LegacyCamera",
                      "Size": 5685
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.VehicleController",
                      "Size": 5484
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ControlModule.ActionController",
                      "Size": 5275
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.BaseOcclusion",
                      "Size": 5054
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.ServerAuthority",
                      "Size": 4887
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VehicleCamera.VehicleCameraConfig",
                      "Size": 4234
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.ConnectionUtil",
                      "Size": 3951
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.CameraToggleStateController",
                      "Size": 3888
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.EventBus",
                      "Size": 3117
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.CameraUI",
                      "Size": 2623
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils",
                      "Size": 2244
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CameraModule.VRCameraTeleportDetector",
                      "Size": 1874
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.FlagUtil",
                      "Size": 1622
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.PlayerModuleEventBus",
                      "Size": 1217
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.VRFirstPersonState",
                      "Size": 941
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 728434
                },
                {
                  "Children": [
                    {
                      "Name": "StarterPlayer.PlayerModule.PlayerScriptsLoader",
                      "Size": 1480
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 1480
                }
              ],
              "Name": "StarterPlayer",
              "Size": 729914
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "Workspace.Player2.Animate",
                      "Size": 125948
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 125948
                }
              ],
              "Name": "Workspace",
              "Size": 125948
            }
          ],
          "Name": "ScriptMemory",
          "Size": 1964021
        }
      },
      "Server": {
        "at": "2026-10-27T14:19:29Z",
        "phase": "soak-840",
        "GetUnparentedInstancesAsync": {
          "Children": [
            {
              "Children": [
                {
                  "Name": "AnimationTrack",
                  "Size": 84
                },
                {
                  "Name": "Path",
                  "Size": 4
                }
              ],
              "Name": "ServerScriptService.GoblinAI",
              "Size": 88
            },
            {
              "Children": [
                {
                  "Name": "BindableEvent",
                  "Size": 1
                }
              ],
              "Name": "StarterPlayer.PlayerModule.CommonUtils.PlayerModuleEventBus",
              "Size": 1
            }
          ],
          "Name": "UnparentedInstances",
          "Size": 89
        },
        "GetAudioMemoryAsync": {
          "Children": [],
          "Name": "AudioMemory",
          "Size": 0
        },
        "GetScriptMemoryAsync": {
          "Children": [
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinConfig",
                      "Size": 33384
                    },
                    {
                      "Name": "ReplicatedStorage.Goblin.GoblinAnimData",
                      "Size": 19765
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 53149
                }
              ],
              "Name": "ReplicatedStorage",
              "Size": 53149
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "ServerScriptService.GoblinHorde",
                      "Size": 331619
                    },
                    {
                      "Name": "ServerScriptService.GoblinAI",
                      "Size": 79793
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 411412
                }
              ],
              "Name": "ServerScriptService",
              "Size": 411412
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.EventBus",
                      "Size": 3271
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils",
                      "Size": 2244
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.FlagUtil",
                      "Size": 1699
                    },
                    {
                      "Name": "StarterPlayer.PlayerModule.CommonUtils.PlayerModuleEventBus",
                      "Size": 1375
                    }
                  ],
                  "Name": "ModuleScripts",
                  "Size": 8589
                },
                {
                  "Children": [
                    {
                      "Name": "StarterPlayer.PlayerModule.InputSetup",
                      "Size": 17433
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 17433
                }
              ],
              "Name": "StarterPlayer",
              "Size": 26022
            },
            {
              "Children": [
                {
                  "Children": [
                    {
                      "Name": "Workspace.Player2.Health",
                      "Size": 2563
                    }
                  ],
                  "Name": "Scripts",
                  "Size": 2563
                }
              ],
              "Name": "Workspace",
              "Size": 2563
            }
          ],
          "Name": "ScriptMemory",
          "Size": 631211
        }
      }
    }
  }
}
]====]
