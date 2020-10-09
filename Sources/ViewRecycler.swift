// Copyright 2016 LinkedIn Corp.
// Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
// You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
import ObjectiveC
import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#endif

/**
 Provides APIs to recycle views by id.
 
 Initialize ViewRecycler with a root view whose subviews are eligible for recycling.
 Call `makeView(layoutId:)` to recycle or create a view of the desired type and id.
 Call `purgeViews()` to remove all unrecycled views from the view hierarchy.
 Call `markViewsAsRoot(views:)` to mark the top level views of generated view hierarchy
 */
class ViewRecycler {

    private var viewStorage = ViewRecyclerViewStorage()
    #if os(iOS) || os(tvOS)
    private let defaultLayerAnchorPoint = CGPoint(x: 0.5, y: 0.5)
    private let defaultTransform = CGAffineTransform.identity
    #endif

    /// Retains all subviews of rootView for recycling.
    init(rootView: View?) {
        guard let rootView = rootView else {
            return
        }

        // Mark all direct subviews from rootView as managed.
        // We are recreating the layout they were previously roots of.
        for view in rootView.subviews where view.type == .root {
            view.type = .managed
        }
        
        rootView.walkSubviews { view in
             self.viewStorage.add(view: view)
         }
    }

    /**
     Returns a view for the layout.
     It may recycle an existing view or create a new view.
     */
    
    func makeOrRecycleView(havingViewReuseId viewReuseId: String?, orViewReuseGroup viewReuseGroup: String?, viewProvider: () -> View) -> View? {

        // If we have a recyclable view that matches type and id, then reuse it.
        if let viewReuseId = viewReuseId, let view = self.viewStorage.popView(withReuseId: viewReuseId) {
            if view.layer.anchorPoint != defaultLayerAnchorPoint {
                view.layer.anchorPoint = defaultLayerAnchorPoint
            }

            if view.transform != defaultTransform {
                view.transform = defaultTransform
            }
            return view
        }
        if let viewGroup = viewReuseGroup, let view = self.viewStorage.popView(withReuseGroup: viewGroup) {
            if view.layer.anchorPoint != defaultLayerAnchorPoint {
                view.layer.anchorPoint = defaultLayerAnchorPoint
            }

            if view.transform != defaultTransform {
                view.transform = defaultTransform
            }
            return view
        }
        
        let providedView = viewProvider()
        providedView.type = .managed
        providedView.viewReuseId = viewReuseId
        providedView.viewReuseGroup = viewReuseGroup
        self.viewStorage.remove(view: providedView)
        return providedView
    }

    /// Removes all unrecycled views from the view hierarchy.
    func purgeViews() {
        self.viewStorage.foreach { view in
            if view.type == .managed {
                view.removeFromSuperview()
            }
        }
        self.viewStorage.removeAll()
    }

    func markViewsAsRoot(_ views: [View]) {
        views.forEach { $0.type = .root }
    }
}

private var viewReuseIdKey: UInt8 = 0
private var typeKey: UInt8 = 0
private var viewReuseGroupKey: UInt8 = 0

extension View {

    enum ViewType: UInt8 {
        // Indicates the view was not created by LayoutKit and should not be modified.
        case unmanaged
        // Indicates the view is managed by LayoutKit that can be safely removed.
        case managed
        // Indicates the view is managed by LayoutKit and is a root of a view hierarchy instantiated (or updated) by `makeViews`.
        // Used to separate such nested hierarchies so that updating the outer hierarchy doesn't disturb any nested hierarchies.
        case root
    }
    
    /// Calls visitor for each transitive subview.
    func walkSubviews(visitor: (View) -> Void) {
        for subview in subviews {
            visitor(subview)
            subview.walkSubviews(visitor: visitor)
        }
    }

    /// Calls visitor for each transitive subview.
    func walkNonRootSubviews(visitor: (View) -> Void) {
        for subview in subviews where subview.type != .root {
            visitor(subview)
            subview.walkNonRootSubviews(visitor: visitor)
        }
    }

    public internal(set) var viewReuseGroup: String? {
        get {
            return objc_getAssociatedObject(self, &viewReuseGroupKey) as? String
        }
        set {
            objc_setAssociatedObject(self, &viewReuseGroupKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    /// Identifies the layout that was used to create this view.
    public internal(set) var viewReuseId: String? {
        get {
            return objc_getAssociatedObject(self, &viewReuseIdKey) as? String
        }
        set {
            objc_setAssociatedObject(self, &viewReuseIdKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }

    var type: ViewType {
        get {
            return objc_getAssociatedObject(self, &typeKey) as? ViewType ?? .unmanaged
        }
        set {
            let type: ViewType? = (newValue == .unmanaged) ? nil : newValue
            objc_setAssociatedObject(self, &typeKey, type, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
}
