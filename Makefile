PRJNAME := kots
OUTPUT := binaries/
TILES := data/chapter_completed_tiles.inc\
	data/end_of_demo_tiles.inc data/title_tiles.inc\
	data/game_over_tiles.inc data/sprite_tiles.inc\
	data/boss_sprite_tiles.inc data/minimap_tiles.inc\
	data/misc_sprite_tiles.inc data/splash_tiles.inc
TILEMAPS := data/chapter_completed_tilemap.inc\
	data/end_of_demo_tilemap.inc data/title_tilemap.inc\
	data/game_over_tilemap.inc data/minimap_tilemap.inc\
	data/splash_tilemap.inc
PSGS := data/minimap.psg data/eod.psg data/title.psg data/boss.psg\
	data/stage_clear.psg data/score_tally.psg data/tick.psg data/coin.psg

all: $(PSGS) $(TILES) $(TILEMAPS) $(OUTPUT)$(PRJNAME).sms

$(OUTPUT)$(PRJNAME).sms: $(PRJNAME).asm libraries/* data/* *.asm
	@C:\Users\ANSJ\Documents\wla_dx_9.12\wla-z80.exe -o $(PRJNAME).o $(PRJNAME).asm
	@echo [objects] > linkfile
	@echo $(PRJNAME).o >> linkfile
	@C:\Users\ANSJ\Documents\wla_dx_9.12\wlalink.exe -d -v -S linkfile $(OUTPUT)$(PRJNAME).sms
	@rm *.o linkfile

data/misc_sprite_tiles.inc: data/img/misc_sprites.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/misc_sprites.png -noremovedupes -8x8 -palsms -fullpalette -savetiles data/misc_sprite_tiles.inc -exit

data/sprite_tiles.inc: data/img/sprites.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/sprites.png -noremovedupes -8x8 -palsms -fullpalette -savetiles data/sprite_tiles.inc -exit

data/village_tiles.inc: data/img/village.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/village.png -noremovedupes -8x8 -palsms -fullpalette -savetiles data/village_tiles.inc -exit

data/village_tilemap.bin: data/map/village.tmx
	node tools/convert_map.js data/map/village.tmx data/village_tilemap.bin

data/boss_sprite_tiles.inc: data/img/boss_sprites.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/boss_sprites.png -noremovedupes -8x8 -palsms -fullpalette -savetiles data/boss_sprite_tiles.inc -exit

data/boss_tiles.inc: data/img/boss.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/boss.png -noremovedupes -8x8 -palsms -fullpalette -savetiles data/boss_tiles.inc -exit

data/boss_tilemap.bin: data/map/boss.tmx
	node tools/convert_map.js data/map/boss.tmx data/boss_tilemap.bin

data/chapter_completed_tiles.inc: data/img/chapter_completed.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/chapter_completed.png -8x8 -palsms -fullpalette -savetiles data/chapter_completed_tiles.inc -exit

data/chapter_completed_tilemap.inc: data/img/chapter_completed.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/chapter_completed.png -8x8 -palsms -fullpalette -savetilemap data/chapter_completed_tilemap.inc -tileoffset 256 -exit

data/end_of_demo_tiles.inc: data/img/end_of_demo.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/end_of_demo.png -8x8 -palsms -fullpalette -savetiles data/end_of_demo_tiles.inc -exit

data/end_of_demo_tilemap.inc: data/img/end_of_demo.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/end_of_demo.png -8x8 -palsms -fullpalette -savetilemap data/end_of_demo_tilemap.inc -tileoffset 256 -exit

data/title_tiles.inc: data/img/title.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/title.png -8x8 -palsms -fullpalette -savetiles data/title_tiles.inc -exit

data/title_tilemap.inc: data/img/title.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/title.png -8x8 -palsms -fullpalette -savetilemap data/title_tilemap.inc -tileoffset 256 -exit

data/game_over_tiles.inc: data/img/game_over.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/game_over.png -8x8 -palsms -fullpalette -savetiles data/game_over_tiles.inc -exit

data/game_over_tilemap.inc: data/img/game_over.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/game_over.png -8x8 -palsms -fullpalette -savetilemap data/game_over_tilemap.inc -exit

data/minimap_tiles.inc: data/img/minimap.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/minimap.png -8x8 -palsms -fullpalette -savetiles data/minimap_tiles.inc -exit

data/minimap_tilemap.inc: data/img/minimap.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/minimap.png -8x8 -palsms -fullpalette -tileoffset 256 -savetilemap data/minimap_tilemap.inc -exit

data/splash_tiles.inc: data/img/splash.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/splash.png -8x8 -palsms -fullpalette -savetiles data/splash_tiles.inc -exit

data/splash_tilemap.inc: data/img/splash.png
	@C:\Users\ANSJ\Documents\bmp2tile042\BMP2Tile.exe data/img/splash.png -8x8 -palsms -fullpalette -tileoffset 256 -savetilemap data/splash_tilemap.inc -exit


data/%.psg: data/psg/%.vgm
	@C:\Users\ANSJ\Documents\PSGlib-nov15\tools\vgm2psg.exe $< $@

