//
//  shengciWidgetBundle.swift
//  shengciWidget
//
//  Created by Dwiki on 28/07/26.
//

import WidgetKit
import SwiftUI

#if WIDGET_EXTENSION
@main
struct shengciWidgetBundle: WidgetBundle {
    var body: some Widget {
        shengciWidget()
    }
}
#else
struct shengciWidgetBundle: WidgetBundle {
    var body: some Widget {
        shengciWidget()
    }
}
#endif
