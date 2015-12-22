/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This view controller contains the Model IO code which is the focus of the sample, which is the loading of voxels. The voxels are displayed using SceneKit as an example graphics library.
 */
@import SceneKit;
@import ModelIO;
@import SceneKit.ModelIO;

#import "AAPLSceneViewController.h"

@implementation AAPLSceneViewController
{
    SCNNode *_character;
    SCNNode *_voxels;
    BOOL _explodeUsingCubes;
}

#define SCALE_FACTOR 0.1

static float rnd()
{
    return 0.01 * SCALE_FACTOR * ((rand() / (float)RAND_MAX) - 0.5);
}

 // Set up scene with character.scn asset and set view properties
- (void) awakeFromNib
{
#if TARGET_OS_IPHONE
    self.sceneView = (SCNView *)self.view;
    
    // Set up tap gesture recognizer
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
    [self.view addGestureRecognizer:tapGesture];
#endif
    
    // Load scene from file path
    SCNScene *characterScene = [SCNScene sceneNamed:@"character.scnassets/character.scn"];

    // For each static physics body in the scene, set its shape and remove the node's geometry so it doesn't appear in the scene.
    SCNNode *collisionNode = [characterScene.rootNode childNodeWithName:@"collision" recursively:YES];
    [collisionNode enumerateChildNodesUsingBlock:^(SCNNode * __nonnull child, BOOL * __nonnull stop)
    {
        child.physicsBody.physicsShape =[SCNPhysicsShape shapeWithGeometry:child.geometry options:nil];
        child.geometry = nil;
    }];

    // Set view properties and defaults
    _character = [characterScene.rootNode childNodeWithName:@"character" recursively:YES];
    self.sceneView.scene = characterScene;
    self.sceneView.jitteringEnabled = YES;
    self.sceneView.allowsCameraControl = NO;
}

- (IBAction)voxelize:(id)sender
{
    // Create MDLAsset from scene
    SCNScene *tempScene = [SCNScene scene];
    [tempScene.rootNode addChildNode:_character];
    MDLAsset *asset = [MDLAsset assetWithSCNScene:tempScene];
    
    // Create voxel grid from MDLAsset
    MDLVoxelArray *grid = [[MDLVoxelArray alloc]  initWithAsset:asset divisions:25 interiorShells:0 exteriorShells:0 patchRadius:0.f];
    NSData *voxelData = [grid voxelIndices];   // retrieve voxel data
    if (voxelData && voxelData.bytes)
    {
        // Create voxel parent node and add to scene
        [_voxels removeFromParentNode];
        _voxels = [SCNNode node];
        [self.sceneView.scene.rootNode addChildNode:_voxels];
        
        // Create the voxel node geometry
        SCNBox *particle = [SCNBox boxWithWidth:2.f * SCALE_FACTOR height:2.f * SCALE_FACTOR length:2.f * SCALE_FACTOR chamferRadius:0.f];
        
        // Get the character's texture map and convert to a bitmap
        NSURL *url = _character.childNodes[0].geometry.firstMaterial.diffuse.contents;
        assert([url isKindOfClass:NSURL.class]); // this sample assumes that the `diffuse` material property is an URL to an image
        CGImageRef image;
#if TARGET_OS_IPHONE
        image = [[UIImage imageWithContentsOfFile:[url path]] CGImage];
#else
        image = [[[NSImage alloc] initByReferencingURL:url] CGImageForProposedRect:nil context:nil hints:nil];
#endif
        CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(image));
        UInt8 *buf = (UInt8 *)CFDataGetBytePtr(pixelData);
        size_t w = CGImageGetWidth(image);
        size_t h = CGImageGetHeight(image);
        size_t bpr = CGImageGetBytesPerRow(image); // this sample assumes 8 bits per component
        size_t bpp = CGImageGetBitsPerPixel(image) / 8;
        
        // Traverse the NSData voxel array and for each ijk index, create a voxel node positioned at its spatial location
        MDLVoxelIndex *voxels = (MDLVoxelIndex *)voxelData.bytes;
        size_t count = voxelData.length / sizeof(MDLVoxelIndex);
        for (int i = 0; i < count; ++i)
        {
            vector_float3 position = [grid spatialLocationOfIndex:*voxels++];
            
#define OFFSET_FACTOR 0.9
            // Determine color of the voxel by performing a hit test and then getting the texture coordinate at the point of intersection
            NSArray *results = [self.sceneView.scene.rootNode
                                hitTestWithSegmentFromPoint:SCNVector3Make(position.x, position.y, position.z + 1.f)
                                toPoint:SCNVector3Make(position.x  * OFFSET_FACTOR , position.y  * OFFSET_FACTOR, position.z - 5.f)
                                options:@{SCNHitTestRootNodeKey : _character, SCNHitTestBackFaceCullingKey : @(NO)}];
#if TARGET_OS_IPHONE
            UIColor *color = [UIColor darkGrayColor]; // default voxel color
#else
            NSColor *color = [NSColor darkGrayColor];
#endif
            if (results.count)
            {
                SCNHitTestResult *result = results[0];
                CGPoint tx = [result textureCoordinatesWithMappingChannel:0];
                // Get the bitmap pixel color at the texture coordinate
                int x = tx.x * w;
                int y = tx.y * h;
                int pixel = bpr * round(y) + bpp * round(x);
                CGFloat r = (CGFloat)buf[pixel] / (CGFloat)255.0; // this sample code assumes that the first 3 components are R, G and B
                CGFloat g = (CGFloat)buf[pixel+1] / (CGFloat)255.0;
                CGFloat b = (CGFloat)buf[pixel+2] / (CGFloat)255.0;
#if TARGET_OS_IPHONE
                color = [UIColor colorWithRed:r green:g blue:b alpha:1];
#else
                color = [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1];
#endif
            }
            
            // Create the voxel node and set its properties
            SCNNode *voxelNode = [SCNNode nodeWithGeometry:[particle copy]];
            voxelNode.position = SCNVector3Make(position.x + rnd(), position.y, position.z + rnd());
            SCNMaterial *material = [SCNMaterial material];
            material.diffuse.contents = color;
            material.selfIllumination.contents = @"character.scnassets/textures/max_ambiant.png";
            voxelNode.geometry.firstMaterial = material;
            
            // Add voxel node to the scene
            [_voxels addChildNode:voxelNode];
        }
        _explodeUsingCubes = true;
        CFRelease(pixelData);
    }
}

- (IBAction)dispalyVoxelsAsCubes:(id)sender
{
    if (!_explodeUsingCubes)
    {
        SCNBox *cube = [SCNBox boxWithWidth:2.f * SCALE_FACTOR height:2.f * SCALE_FACTOR length:2.f * SCALE_FACTOR chamferRadius:0.f];
        
        // For each voxel node, change its geometry to a cube
        [_voxels enumerateChildNodesUsingBlock:^(SCNNode * child, BOOL * stop)
         {
             SCNMaterial *material = child.geometry.firstMaterial;
             child.geometry = [cube copy];
             child.geometry.firstMaterial = material;
         }];
        _explodeUsingCubes = true;
    }
}

- (IBAction)dispalyVoxelsAsSpheres:(id)sender
{
    if (_explodeUsingCubes)
    {
        SCNSphere *sphere = [SCNSphere sphereWithRadius:1.f * SCALE_FACTOR];
        
        // For each voxel node, change its geometry to a sphere
        [_voxels enumerateChildNodesUsingBlock:^(SCNNode * child, BOOL * stop)
         {
             SCNMaterial *material = child.geometry.firstMaterial;
             child.geometry = [sphere copy];
             child.geometry.firstMaterial = material;
         }];
        _explodeUsingCubes = false;
    }
}

- (IBAction)explode:(id)sender
{
    // The shape of the physics body varies depending on the geometry of the voxel node
    SCNGeometry *particle;
    if (_explodeUsingCubes)
    {
        particle = [SCNBox boxWithWidth:1.9 * SCALE_FACTOR height:1.9 * SCALE_FACTOR length:1.9 * SCALE_FACTOR chamferRadius:0.f];
    } else
    {
        particle = [SCNSphere sphereWithRadius:0.9 * SCALE_FACTOR];
    }
    
    // For each voxel node, apply a physics force
    [_voxels enumerateChildNodesUsingBlock:^(SCNNode * child, BOOL * stop)
     {
         child.physicsBody = [SCNPhysicsBody dynamicBody];
         child.physicsBody.physicsShape = [SCNPhysicsShape shapeWithGeometry:particle options:nil];
         [child.physicsBody applyForce:SCNVector3Make(rnd() * 1000.f, 3.f + 100.f * rnd(), rnd() * 1000.f) atPosition:SCNVector3Make(0.f, 0.f, 0.f) impulse:YES];
     }];
}

- (IBAction)reset:(id)sender
{
    [_voxels removeFromParentNode];
    [self.sceneView.scene.rootNode addChildNode:_character];
}

#if TARGET_OS_IPHONE
- (void)handleTapGesture:(UITapGestureRecognizer *)gesture
{
    CGRect targetRectangle = CGRectMake(self.view.bounds.size.width * .5 - 50, self.view.bounds.size.height * .25, 100, 100);
    [[UIMenuController sharedMenuController] setTargetRect:targetRectangle inView:self.view];
    
    // Create custom menu items
    UIMenuItem *voxelizeMenuItem = [[UIMenuItem alloc] initWithTitle:@"Voxelize" action:@selector(voxelize:)];
    UIMenuItem *cubesMenuItem = [[UIMenuItem alloc] initWithTitle:@"Cubes" action:@selector(dispalyVoxelsAsCubes:)];
    UIMenuItem *spheresMenuItem = [[UIMenuItem alloc] initWithTitle:@"Spheres" action:@selector(dispalyVoxelsAsSpheres:)];
    UIMenuItem *explodeMenuItem = [[UIMenuItem alloc] initWithTitle:@"Explode" action:@selector(explode:)];
    UIMenuItem *resetMenuItem = [[UIMenuItem alloc] initWithTitle:@"Reset" action:@selector(reset:)];
    
    // Add menu items to shared menu controller
    [[UIMenuController sharedMenuController] setMenuItems:@[voxelizeMenuItem, cubesMenuItem, spheresMenuItem, explodeMenuItem, resetMenuItem]];
    
    // Make menu controller visible
    [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action == @selector(voxelize:) || action == @selector(dispalyVoxelsAsCubes:) || action == @selector(dispalyVoxelsAsSpheres:) ||
        action == @selector(explode:) || action == @selector(reset:))
    {
        return YES;
    }
    return NO;
}
#endif

@end
