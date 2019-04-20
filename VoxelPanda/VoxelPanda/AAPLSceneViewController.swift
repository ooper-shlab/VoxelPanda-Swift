//
//  AAPLSceneViewController.swift
//  VoxelPanda
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/12/21.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 This view controller contains the Model IO code which is the focus of the sample, which is the loading of voxels. The voxels are displayed using SceneKit as an example graphics library.
 */

#if os(OSX)
    import Cocoa
    typealias BaseViewController = NSViewController
    typealias SCNVectorFloat = CGFloat
#else
    import UIKit
    typealias BaseViewController = UIViewController
    typealias SCNVectorFloat = Float
#endif
import SceneKit
import ModelIO
import SceneKit.ModelIO

private let SCALE_FACTOR: CGFloat = 0.1

private func rnd() -> SCNVectorFloat {
    return 0.01 * SCNVectorFloat(SCALE_FACTOR) * ((SCNVectorFloat(arc4random()) / SCNVectorFloat(RAND_MAX)) - 0.5)
}

@objc(AAPLSceneViewController)
class AAPLSceneViewController: BaseViewController {
    
    
    @IBOutlet weak var sceneView: SCNView!
    
    fileprivate var _character: SCNNode!
    fileprivate var _voxels: SCNNode?
    fileprivate var _explodeUsingCubes: Bool = false
    
    // Set up scene with character.scn asset and set view properties
    override func awakeFromNib() {
        //#if TARGET_OS_IPHONE
        //    self.sceneView = (SCNView *)self.view;
        //
        //    // Set up tap gesture recognizer
        //    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTapGesture:)];
        //    [self.view addGestureRecognizer:tapGesture];
        //#endif
        
        // Load scene from file path
        let characterScene = SCNScene(named: "character.scnassets/character.scn")!
        
        // For each static physics body in the scene, set its shape and remove the node's geometry so it doesn't appear in the scene.
        let collisionNode = characterScene.rootNode.childNode(withName: "collision", recursively: true)!
        collisionNode.enumerateChildNodes{child, stop in
            child.physicsBody!.physicsShape = SCNPhysicsShape(geometry: child.geometry!, options: nil)
            child.geometry = nil
        }
        
        // Set view properties and defaults
        _character = characterScene.rootNode.childNode(withName: "character", recursively: true)!
        self.sceneView.scene = characterScene
        self.sceneView.isJitteringEnabled = true
        self.sceneView.allowsCameraControl = false
    }
    
    @IBAction func voxelize(_: Any) {
        // Create MDLAsset from scene
        let tempScene = SCNScene()
        tempScene.rootNode.addChildNode(_character)
        let asset = MDLAsset(scnScene: tempScene)
        
        // Create voxel grid from MDLAsset
        let grid = MDLVoxelArray(asset: asset, divisions: 25, interiorShells: 0, exteriorShells: 0, patchRadius: 0.0)
        if let voxelData = grid.voxelIndices() {   // retrieve voxel data
            // Create voxel parent node and add to scene
            _voxels?.removeFromParentNode()
            _voxels = SCNNode()
            self.sceneView.scene?.rootNode.addChildNode(_voxels!)
            
            // Create the voxel node geometry
            let particle = SCNBox(width: 2.0 * SCALE_FACTOR, height: 2.0 * SCALE_FACTOR, length: 2.0 * SCALE_FACTOR, chamferRadius: 0.0)
            
            // Get the character's texture map and convert to a bitmap
            let contents = _character.childNodes[0].geometry!.firstMaterial!.diffuse.contents
            let url: URL // this sample assumes that the `diffuse` material property is an URL to an image
            if let theUrl = contents as? URL {
                url = theUrl
            } else {
                //### Or a relative path string to an image
                let thePath = contents as! String
                url = Bundle.main.url(forResource: thePath, withExtension: nil)!
            }
            let image: CGImage
            #if os(iOS)
                //        image = [[UIImage imageWithContentsOfFile:[url path]] CGImage];
            #else
                image = NSImage(byReferencing: url).cgImage(forProposedRect: nil, context: nil, hints: nil)!
            #endif
            let pixelData = image.dataProvider?.data!
            let buf = CFDataGetBytePtr(pixelData)
            let w = image.width
            let h = image.height
            let bpr = image.bytesPerRow // this sample assumes 8 bits per component
            let bpp = image.bitsPerPixel / 8
            
            // Traverse the NSData voxel array and for each ijk index, create a voxel node positioned at its spatial location
            voxelData.withUnsafeBytes {voxelBytes in
                let voxels = voxelBytes.bindMemory(to: MDLVoxelIndex.self).baseAddress!
                let count = voxelData.count / MemoryLayout<MDLVoxelIndex>.size
                for i in 0..<count {
                    let position = grid.spatialLocation(ofIndex: voxels[i])
                    
                    let OFFSET_FACTOR: SCNVectorFloat = 0.9
                    // Determine color of the voxel by performing a hit test and then getting the texture coordinate at the point of intersection
                    let results = self.sceneView.scene!.rootNode
                        .hitTestWithSegment(from: SCNVector3Make(SCNVectorFloat(position.x), SCNVectorFloat(position.y), SCNVectorFloat(position.z) + 1.0),
                                            to: SCNVector3Make(SCNVectorFloat(position.x)  * OFFSET_FACTOR , SCNVectorFloat(position.y)  * OFFSET_FACTOR, SCNVectorFloat(position.z) - 5.0),
                                            options: [SCNHitTestOption.rootNode.rawValue : _character!, SCNHitTestOption.backFaceCulling.rawValue : false])
                    #if os(iOS)
                        var color = UIColor.darkGray // default voxel color
                    #else
                        var color = NSColor.darkGray
                    #endif
                    if !results.isEmpty {
                        let result = results[0]
                        let tx = result.textureCoordinates(withMappingChannel: 0)
                        // Get the bitmap pixel color at the texture coordinate
                        let x = tx.x * CGFloat(w)
                        let y = tx.y * CGFloat(h)
                        let pixel = bpr * Int(round(y)) + bpp * Int(round(x))
                        let r = CGFloat((buf?[pixel])!) / 255.0 // this sample code assumes that the first 3 components are R, G and B
                        let g = CGFloat((buf?[pixel+1])!) / 255.0
                        let b = CGFloat((buf?[pixel+2])!) / 255.0
                        #if os(iOS)
                            color = UIColor(red:r, green: g, blue: b, alpha: 1)
                        #else
                            color = NSColor(calibratedRed: r, green: g, blue:b, alpha: 1)
                        #endif
                    }
                    
                    // Create the voxel node and set its properties
                    let voxelNode = SCNNode(geometry: (particle.copy() as! SCNGeometry))
                    voxelNode.position = SCNVector3Make(SCNVectorFloat(position.x) + rnd(), SCNVectorFloat(position.y), SCNVectorFloat(position.z) + rnd())
                    let material = SCNMaterial()
                    material.diffuse.contents = color
                    material.selfIllumination.contents = "character.scnassets/textures/max_ambiant.png"
                    voxelNode.geometry!.firstMaterial = material
                    
                    // Add voxel node to the scene
                    _voxels!.addChildNode(voxelNode)
                }
            }
            _explodeUsingCubes = true
        }
    }
    
    @IBAction func dispalyVoxelsAsCubes(_: Any) {
        if !_explodeUsingCubes {
            let cube = SCNBox(width: 2.0 * SCALE_FACTOR, height: 2.0 * SCALE_FACTOR, length: 2.0 * SCALE_FACTOR, chamferRadius: 0.0)
            
            // For each voxel node, change its geometry to a cube
            _voxels?.enumerateChildNodes{child, stop in
                let material = child.geometry?.firstMaterial
                child.geometry = (cube.copy() as! SCNGeometry)
                child.geometry!.firstMaterial = material
            }
            _explodeUsingCubes = true
        }
    }
    
    @IBAction func dispalyVoxelsAsSpheres(_: Any) {
        if _explodeUsingCubes {
            let sphere = SCNSphere(radius: 1.0 * SCALE_FACTOR)
            
            // For each voxel node, change its geometry to a sphere
            _voxels?.enumerateChildNodes{child, stop in
                let material = child.geometry?.firstMaterial
                child.geometry = (sphere.copy() as! SCNGeometry)
                child.geometry!.firstMaterial = material
            }
            _explodeUsingCubes = false
        }
    }
    
    @IBAction func explode(_: Any) {
        // The shape of the physics body varies depending on the geometry of the voxel node
        let particle: SCNGeometry
        if _explodeUsingCubes {
            particle = SCNBox(width: 1.9 * SCALE_FACTOR, height: 1.9 * SCALE_FACTOR, length: 1.9 * SCALE_FACTOR, chamferRadius: 0.0)
        } else {
            particle = SCNSphere(radius: 0.9 * SCALE_FACTOR)
        }
        
        // For each voxel node, apply a physics force
        _voxels?.enumerateChildNodes{child, stop in
            child.physicsBody = SCNPhysicsBody.dynamic()
            child.physicsBody!.physicsShape = SCNPhysicsShape(geometry: particle, options: nil)
            child.physicsBody!.applyForce(SCNVector3Make(rnd() * 1000.0, 3.0 + 100.0 * rnd(), rnd() * 1000.0), at: SCNVector3Make(0.0, 0.0, 0.0), asImpulse: true)
        }
    }
    
    @IBAction func reset(_: Any) {
        _voxels?.removeFromParentNode()
        self.sceneView.scene!.rootNode.addChildNode(_character)
    }
    
    //#if TARGET_OS_IPHONE
    //- (void)handleTapGesture:(UITapGestureRecognizer *)gesture
    //{
    //    CGRect targetRectangle = CGRectMake(self.view.bounds.size.width * .5 - 50, self.view.bounds.size.height * .25, 100, 100);
    //    [[UIMenuController sharedMenuController] setTargetRect:targetRectangle inView:self.view];
    //
    //    // Create custom menu items
    //    UIMenuItem *voxelizeMenuItem = [[UIMenuItem alloc] initWithTitle:@"Voxelize" action:@selector(voxelize:)];
    //    UIMenuItem *cubesMenuItem = [[UIMenuItem alloc] initWithTitle:@"Cubes" action:@selector(dispalyVoxelsAsCubes:)];
    //    UIMenuItem *spheresMenuItem = [[UIMenuItem alloc] initWithTitle:@"Spheres" action:@selector(dispalyVoxelsAsSpheres:)];
    //    UIMenuItem *explodeMenuItem = [[UIMenuItem alloc] initWithTitle:@"Explode" action:@selector(explode:)];
    //    UIMenuItem *resetMenuItem = [[UIMenuItem alloc] initWithTitle:@"Reset" action:@selector(reset:)];
    //
    //    // Add menu items to shared menu controller
    //    [[UIMenuController sharedMenuController] setMenuItems:@[voxelizeMenuItem, cubesMenuItem, spheresMenuItem, explodeMenuItem, resetMenuItem]];
    //
    //    // Make menu controller visible
    //    [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
    //}
    //
    //- (BOOL)canBecomeFirstResponder {
    //    return YES;
    //}
    //
    //- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
    //{
    //    if (action == @selector(voxelize:) || action == @selector(dispalyVoxelsAsCubes:) || action == @selector(dispalyVoxelsAsSpheres:) ||
    //        action == @selector(explode:) || action == @selector(reset:))
    //    {
    //        return YES;
    //    }
    //    return NO;
    //}
    //#endif
    
}
