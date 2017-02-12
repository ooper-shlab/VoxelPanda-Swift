//
//  AAPLAppDelegate.swift
//  VoxelPanda
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/12/22.
//
//
/*
 Copyright (C) 2015 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 The app delegate is a supporting class within the scope of this sample.
 */
import Cocoa

@NSApplicationMain
@objc(AAPLAppDelegate)
class AAPLAppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

}
