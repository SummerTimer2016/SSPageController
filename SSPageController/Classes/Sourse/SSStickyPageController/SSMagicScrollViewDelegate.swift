//
//  SSMagicScrollViewDelegate.swift
//  JYLMOperation
//
//  Created by Summer on 2021/4/27.
//

import Foundation
/**
 The delegate of a SSMagicScrollView object may adopt the SSMagicScrollViewDelegate protocol to control subview's scrolling effect.
 */
protocol SSMagicScrollViewDelegate: UIScrollViewDelegate {
    /// Asks the page if the scrollview should scroll with the subview.
    /// - Parameters:
    ///   - scrollView: The scrollview. This is the object sending the message.
    ///   - subview:    An instance of a sub view.
    /// - Returns: YES to allow scrollview and subview to scroll together. YES by default.
    func scrollView(_ scrollView: SSMagicScrollView?, shouldScrollWithSubview subview: UIScrollView?) -> Bool
}

extension SSMagicScrollViewDelegate {
    func scrollView(_ scrollView: SSMagicScrollView?,
                    shouldScrollWithSubview subview: UIScrollView?) -> Bool {return false}
}
