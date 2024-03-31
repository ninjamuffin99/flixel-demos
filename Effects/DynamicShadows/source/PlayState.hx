package;

import flixel.util.FlxSort;
import nape.shape.Polygon;
import nape.geom.GeomPoly;
import flixel.group.FlxGroup;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import nape.geom.Ray;
import flixel.FlxCamera;
import flixel.addons.nape.FlxNapeSpace;
import flixel.addons.nape.FlxNapeTilemap;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.tile.FlxTilemap;
import flixel.util.FlxColor;
import nape.geom.Vec2;
import nape.geom.Vec2List;
import nape.phys.Body;
import openfl.display.BlendMode;
import openfl.display.FPS;

using flixel.util.FlxSpriteUtil;

/**
 * This was based on a guide from this forum post: http://forums.tigsource.com/index.php?topic=8803.0
 * Ported to HaxeFlixel by Xerosugar, then converted to use Shaders by GeoKureli
 *
 * If you're feeling up the challenge, here's how YOU help can improve this demo:
 * - Make it possible to extends the shadows to the edge of the screen
 * - Make it possible to use multiple light sources while still maintaining a decent frame rate
 * - Improve the performance of *this* demo
 * - Make it possible to blur the edges of the shadows
 * - Make it possible to limit the light source's influence, or "strength"
 * - Your own ideas? :)
 *
 * @author Tommy Elfving
 */
class PlayState extends FlxState
{
	public static inline var TILE_SIZE:Int = 16;

	/**
	 * Only contains non-collidabe tiles
	 */
	var background:FlxTilemap;

	/**
	 * The layer into which the actual "level" will be drawn, and also the one objects will collide with
	 */
	var foreground:FlxNapeTilemap;
	
	/**
	 *  Anything you want to show above the shadows
	 */
	var uiCam:FlxCamera;
	
	/**
	 * The light source!
	 */
	var gem:Gem;

	var infoText:FlxText;
	var fps:FPS;

	var rayPoints:FlxGroup;
	var canvas:FlxSprite;

	override public function create():Void
	{
		super.create();

		FlxNapeSpace.init();
		FlxNapeSpace.space.gravity.setxy(0, 1200);
		FlxNapeSpace.drawDebug = false; // You can toggle this on/off one by pressing 'D'

		background = new FlxTilemap();
		background.loadMapFromCSV("assets/data/background.txt", "assets/images/tiles.png", TILE_SIZE, TILE_SIZE, null, 1, 1);
		add(background);

		foreground = new FlxNapeTilemap();
		foreground.loadMapFromCSV("assets/data/foreground.txt", "assets/images/tiles.png", TILE_SIZE, TILE_SIZE, null, 1, 1);
		add(foreground);

		foreground.setupTileIndices([4]);
		createProps();

		infoText = new FlxText(10, 10, 100, "");
		add(infoText);

		// This here is only used to get the current FPS in a simple way, without having to run the application in Debug mode
		fps = new FPS(10, 10, 0xffffff);
		FlxG.stage.addChild(fps);
		fps.visible = false;
		

		rayPoints = new FlxGroup();
		add(rayPoints);

		

		createCams();

		canvas = new FlxSprite(0, 0);
		canvas.makeGraphic(FlxG.width, FlxG.height, FlxColor.TRANSPARENT, true);
		canvas.blend = BlendMode.MULTIPLY;
		add(canvas);
		
		// trace(FlxNapeSpace.space.liveBodies.length);
	}
	
	function createCams()
	{
		// FlxG.camera draws the actual world. In this case, that means everything except infoText
		FlxG.camera.bgColor = 0x5a81ad;
		gem.camera = FlxG.camera;
		background.camera = FlxG.camera;
		
		// draws anything above the sahdows, in this case infoText
		uiCam = new FlxCamera(0, 0, FlxG.width, FlxG.height);
		FlxG.cameras.add(uiCam, false);
		uiCam.bgColor = 0x0;
		infoText.camera = uiCam;
	}

	function createProps():Void
	{
		for (tileY in 0...foreground.heightInTiles)
		{
			for (tileX in 0...foreground.widthInTiles)
			{
				var tileIndex = foreground.getTile(tileX, tileY);
				var xPos:Float = tileX * TILE_SIZE;
				var yPos:Float = tileY * TILE_SIZE;

				if (tileIndex == Prop.BARREL)
				{
					add(new Barrel(xPos, yPos));
					cleanTile(tileX, tileY);
				}
				else if (tileIndex == Prop.GEM)
				{
					gem = new Gem(xPos, yPos);
					add(gem);
					cleanTile(tileX, tileY);
				}
			}
		}
	}

	/**
	 * The tile in question was replaced by an actual object, this function will clean up the tile for us
	 */
	function cleanTile(x:Int, y:Int):Void
	{
		foreground.setTile(x, y, 0);
	}



	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		rayPoints.killMembers();
		rayPoints.clear();
		
		var vertsForPoly:Array<Vec2> = [];

		for (body in FlxNapeSpace.space.bodies)
			{	
				if (body == null)
					continue;
	
				for (shape in body.shapes)
				{
					if (shape.isPolygon())
					{
						var poly = shape.castPolygon;
						var verts = poly.worldVerts;
						for (v in verts)
						{
							var bodyPos = body.position;
							var rays:Array<Ray> = [];
							var ray0 = new Ray(gem.body.position, v.sub(gem.body.position, true));
							var ray1 = ray0.copy();
							var ray2 = ray0.copy();
							ray1.direction = ray1.direction.rotate(0.00001);
							ray2.direction = ray2.direction.rotate(-0.00001);
							
							rays.push(ray0);
							rays.push(ray1);
							rays.push(ray2);

							for (ray in rays)
							{
								var raycastResult = FlxNapeSpace.space.rayCast(ray);
								if (raycastResult != null)
								{
									var rayPos = ray.at(raycastResult.distance);
									
									vertsForPoly.push(rayPos);
									// rayPoints.add(new FlxSprite(rayPos.x, rayPos.y).makeGraphic(4, 4, FlxColor.RED));
								}
							}
							
						}
						
					}

				}
				// var bodyPos = body.position;
				// var ray = new Ray(gem.body.position, bodyPos.sub(gem.body.position, true));
				// var raycastResult = FlxNapeSpace.space.rayCast(ray);
	
				
				
			}
		
		vertsForPoly.sort(function(vec1, vec2) {
			var angle1 = Math.atan2(gem.body.position.y - vec1.y, gem.body.position.x - vec1.x);
			var angle2 = Math.atan2(gem.body.position.y - vec2.y, gem.body.position.x - vec2.x);
			return FlxSort.byValues(FlxSort.ASCENDING, angle1, angle2);
		});
		
		var poly = GeomPoly.get(Vec2List.fromArray(vertsForPoly));

			canvas.fill(0xff2a2963);
			
			var simplePoly = poly;
			var points:Array<FlxPoint> = [];
			for (vert in simplePoly.iterator())
			{
				points.push(new FlxPoint(vert.x, vert.y));
			}
			canvas.drawPolygon(points, 0xff887fff);

			// FlxNapeSpace.shapeDebug.drawFilledPolygon(poly.simplify(0.1), FlxColor.RED);
		

		// poly.triangularDecomposition();

		// var mousePos = FlxG.mouse.getWorldPosition();
		// var mouseVec = new Vec2(mousePos.x, mousePos.y);
		// var ray = new Ray(gem.body.position, mouseVec.sub(gem.body.position, true));
		// var raycastResult = FlxNapeSpace.space.rayCast(ray);


		// if (raycastResult != null)
		// {
		// 	var rayPos = ray.at(raycastResult.distance);
		// 	rayPoint.x = rayPos.x;
		// 	rayPoint.y = rayPos.y;
		// }


		infoText.text = "FPS: " + fps.currentFPS + "\n\nObjects can be dragged/thrown around.\n\nPress 'R' to restart.";

		if (FlxG.keys.justPressed.R)
			FlxG.resetState();

		if (FlxG.keys.justPressed.D)
			FlxNapeSpace.drawDebug = !FlxNapeSpace.drawDebug;
	}
}

enum abstract Prop(Int) to Int
{
	var BARREL = 5;
	var GEM = 6;
}
