﻿package code 
{
	import flash.display.MovieClip;
	import flash.events.MouseEvent;
	import flash.events.Event;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	
	/**
	 * ...
	 * @author Drew Diamantoukos
	 */
	public class WorldMap extends MovieClip 
	{
		private const MAX_TOWNS:int = 5;
		private const MAX_WEEKS:int = 13;
		
		private var gameScreenManager:GameScreens;
		private var towns:Array;
		private var townPopup:TownPopupBox;
		
		private var _mapXml:XMLList;
		private var _currentXML:XMLList;
		private var _gameTextBox:GameTextBox;
		private var _gameDialogBox:GameDialogBox;
		private var _player:Player;
		private var _currentTown:Town;
		private var _weeksLeft:int;
		private var _currentIndex:int;
		private var _currentSection:String;
		
		public function get player():Player { return _player; }
		public function get currentTown():Town { return _currentTown; }
		public function get weeksLeft():int { return _weeksLeft; }
		
		public function WorldMap(aManager:GameScreens)
		{
			gameScreenManager = aManager;
			_player = gameScreenManager.player;
			
			towns = new Array();
			_currentTown = null;
			_mapXml = null;
			_currentXML = null;
			
			initTowns();
			_weeksLeft = MAX_WEEKS;
			
			townPopup = new TownPopupBox();
			townPopup.btnTravel.addEventListener(MouseEvent.CLICK, onTravelClick);
			addChild(townPopup);
			townPopup.visible = false;
			updateInfo();
			
			var textUrlLoader:URLLoader = new URLLoader(new URLRequest("WorldMapText.xml"));
			textUrlLoader.addEventListener(Event.COMPLETE, onTextLoadComplete);
		}
		
		private function onTextLoadComplete(e:Event):void
		{
			_mapXml = new XMLList(e.target.data);
			loadXmlSection();
		}
		
		// Call when day at carnival is done.
		public function returnToOverworld():void
		{
			_weeksLeft--;
			if (_weeksLeft > 0)
			{
				updateInfo();
				gameScreenManager.changeLocation("World Map");
			}
			else
			{
				// TO-DO: Handle the end of game, evaluation, etc.
			}
		}
		
		private function initTowns():void
		{
			for (var i:int = 0; i < MAX_TOWNS; ++i)
			{
				var aTown:Town = new Town(this, "Town " + i, Math.random() * 100 + 1, Math.random() * 100000 + 1, Math.random() * 101);
				aTown.x = Math.random() * gameScreenManager.stage.stageWidth;
				aTown.y = Math.random() * gameScreenManager.stage.stageHeight / 2 + Math.random() * gameScreenManager.stage.stageHeight / 2;
				addChild(aTown);
				towns.push(aTown);
			}
		}
		
		private function onWorldClick(e:MouseEvent):void
		{
			if (e.target is Town)
			{
				if (_currentTown)
				{
					// TO-DO: Pop-up message detailing travel plans, etc.
				}
				
				showPopup(e.target as Town);
			}
			else
			{
				townPopup.visible = false;
				townPopup.unloadInfo();
			}
		}
		
		public function showPopup(aTown:Town):void
		{
			// Don't move the popup box if it's the same town.
			if (townPopup.town == aTown)
				return;
				
			townPopup.visible = true;
			townPopup.loadInfo(aTown);
			townPopup.x = mouseX;
			townPopup.y = mouseY;
			
			// Make sure the entire pop-up box fits in the window.
			if (townPopup.x + townPopup.width >= stage.stageWidth)
				townPopup.x -= (townPopup.x + townPopup.width - stage.stageWidth);
				
			if (townPopup.y + townPopup.height >= stage.stageHeight)
				townPopup.y -= (townPopup.y + townPopup.height - stage.stageHeight);
		}
		
		private function onTravelClick(e:MouseEvent):void
		{
			_currentTown = townPopup.town;
			_currentTown.visitTown();
			gameScreenManager.changeLocation("Overhead Carnival");
		}
		
		private function updateInfo():void
		{
			txtWeeksLeft.text = "Weeks Left: " + _weeksLeft;
			txtWealth.text = "Wealth: " + player.wealth;
		}
		
		// Loads a new section of the XML to display.
		private function loadXmlSection():void
		{
			_currentXML = null;
			_currentIndex = 0;
			for each (var xmlPiece:XML in _mapXml.child("Section"))
			{
				_currentXML = XMLList(xmlPiece);
			}

			if (_currentXML != null)
			{
				_gameTextBox = new GameTextBox(_currentXML.Text[_currentIndex]);
				addChild(_gameTextBox);
				_gameTextBox.addEventListener(MessageEvent.ON_MESSAGE_COMPLETE, onMessageComplete);
			}
		}

		private function onMessageComplete(e:MessageEvent):void
		{
			// Checks null attribute - (_overworldXML.child(_currentChild).Text[_currentIndex].@index).toString() == ""
			// .name() gets the node name.

			if (_currentXML == null)
			{
				clearMessageBox();
				return;
			}

			_currentIndex++;
			// If there is a node to evaluate within bounds.
			if (_currentIndex < _currentXML.children().length())
			{
				// Make sure it is a Text node.
				var nodeName:String = _currentXML.child(_currentIndex).name();
				if (nodeName == "Text")
				{
					_gameTextBox.loadMessage(_currentXML.children()[_currentIndex]);
				}
				// If it is a Dialog node, make this node the new current node to generate messages from.
				else if (nodeName == "Dialog")
				{
					_currentXML = _currentXML.child(_currentIndex).children();
					addDialogBox();
					_gameTextBox.removeEventListener(MessageEvent.ON_MESSAGE_COMPLETE, onMessageComplete);
				}
				else if (nodeName == "Section")
				{
					clearMessageBox();
				}
				return;
			}
			// If we are out of bounds, see if there is more text in a parent node.
			else
			{
				if (_currentXML.parent() != null)
				{
					// We need to find the node whose parent isn't a Dialog node.
					while (_currentXML.parent().name() == "Dialog")
					{
						_currentXML = XMLList(_currentXML.parent());
					}

					// Now, fina the position of this node in the parent of the current node. This is where we continue the tree.
					for (var i:int = 0; i < _currentXML.parent().children().length(); i++ )
					{
						if (_currentXML.parent().child(i) == _currentXML)
						{
							_currentIndex = i;
							_currentXML = XMLList(_currentXML.parent()); // Set the current node to the parent. This is where we left off from.
							// Add and dispatch the events to display new text.
							_gameTextBox.addEventListener(MessageEvent.ON_MESSAGE_COMPLETE, onMessageComplete);
							onMessageComplete(new MessageEvent(MessageEvent.ON_MESSAGE_COMPLETE));
							return;
						}
					}
				}
				clearMessageBox();
			}
		}

		private function clearMessageBox():void
		{
			_gameTextBox.removeEventListener(MessageEvent.ON_MESSAGE_COMPLETE, onMessageComplete);
			removeChild(_gameTextBox);
			this.addEventListener(MouseEvent.CLICK, onWorldClick);
		}

		private function addDialogBox():void
		{
			var choices:Array = new Array();
			for (var i:int = 0; i < _currentXML.length(); i++)
			{
				choices.push(_currentXML[i].@choice);
			}

			_gameDialogBox = new GameDialogBox(choices);
			addChild(_gameDialogBox);
			_gameDialogBox.x = stage.stageWidth - _gameDialogBox.width;
			_gameDialogBox.y = stage.stageHeight / 2 - _gameDialogBox.height / 2;
			_gameDialogBox.addEventListener(MessageEvent.ON_DIALOG_SELECT, onDialogSelect);
		}

		// Remove the dialog box, continue reading text from the xml tree from the choice selected.
		private function onDialogSelect(e:MessageEvent):void
		{
			_gameDialogBox.removeEventListener(MessageEvent.ON_DIALOG_SELECT, onDialogSelect);
			removeChild(_gameDialogBox);

			if (_currentXML[e.dialogSelected].@flag != null)
			{
				switch ((_currentXML[e.dialogSelected].@flag).toString())
				{

				}
			}
			_currentIndex = 0;
			_currentXML = XMLList(_currentXML[e.dialogSelected]);
			_gameTextBox.loadMessage(_currentXML.Text[_currentIndex]);
			_gameTextBox.addEventListener(MessageEvent.ON_MESSAGE_COMPLETE, onMessageComplete);
		}
	}
}