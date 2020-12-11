# WiiMoteGuitar
User space driver for guitar hero Wii remote guitar hero guitars. Generates key events from button presses on connected guitars.

To connect WiiRemotes:
Press "Start Scanning"
Press the red "Sync" button on the back of WiiRemotes

Config File:
No keyboard events will be generated until a config file is loaded. The config file has one line for every configured guitar in the following format. The keycodes are the virtual keycodes which can be found here https://stackoverflow.com/a/16125341 .

<WiiRemote Bluetooth Address>, <greenFret keycode>, <redFret keycode>, <yellowFret keycode>, <blueFret keycode>, <orangeFre keycode>, <strumUp keycode>, <strumDown keycode>, <start keycode>, <select keycode>, <whammyBar keycode>

For example:
00-1e-35-45-45-06, 0x0C, 0x0D, 0x0E, 0x0F, 0x11, 0x10, 0x20, 0x22, 0x1f, 0x23

Finally checking isSendingKeys will enable the program to start generating key presses from the guitar input.

Note: If using with clone hero only one player will be able to take input from the keyboard. To fix see the following mod: https://github.com/tommy1019/CloneHeroKeyboardFix
