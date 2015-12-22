/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 This view controller contains the Model IO code which is the focus of the sample, which is the loading of voxels. The voxels are displayed using SceneKit as an example graphics library.
 */

#if !TARGET_OS_IPHONE
@interface AAPLSceneViewController : NSViewController
#else
@interface AAPLSceneViewController : UIViewController
#endif


@property (weak) IBOutlet SCNView *sceneView;

- (IBAction)voxelize:(id)sender;
- (IBAction)dispalyVoxelsAsCubes:(id)sender;
- (IBAction)dispalyVoxelsAsSpheres:(id)sender;
- (IBAction)explode:(id)sender;
- (IBAction)reset:(id)sender;

@end
