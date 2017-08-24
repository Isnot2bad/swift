//
//  TransitionController.swift
//  ViewOrientation
//
//  Created by larryhou on 16/08/2017.
//  Copyright © 2017 larryhou. All rights reserved.
//

import Foundation
import UIKit

extension UIGestureRecognizerState
{
    var description:String
    {
        switch self
        {
            case .began:return "began"
            case .changed:return "changed"
            case .possible:return "possible"
            case .ended:return "ended"
            case .cancelled:return "cancelled"
            case .failed:return "failed"
        }
    }
}

func clamp<T>(_ value:T, _ lower:T, _ upper:T)->T where T:Comparable
{
    return min(upper, max(lower, value))
}

class InteractiveNavigationController : UINavigationController
{
    var transitionController:NavigationTransitionController!
    
    override func loadView()
    {
        super.loadView()
        transitionController = NavigationTransitionController(navigationController: self, duration: 0.3)
    }
}

class NavigationTransitionController : NSObject
{
    unowned let navigationController:UINavigationController
    private(set) var gesture:UIPanGestureRecognizer
    private(set) var duration:TimeInterval
    private(set) var transitionAnimator:UIViewPropertyAnimator!
    private(set) var transitionContext:UIViewControllerContextTransitioning!
    private(set) var operation:UINavigationControllerOperation = .none
    private(set) var anchor = CGPoint(x: 0.5, y: 0.5)
    
    init(navigationController controller:UINavigationController, duration:TimeInterval = 0.5)
    {
        self.navigationController = controller
        self.gesture = UIPanGestureRecognizer()
        self.duration = duration
        super.init()
        
        self.navigationController.delegate = self
        
        self.gesture.delegate = self
        self.gesture.maximumNumberOfTouches = 1
        self.gesture.addTarget(self, action: #selector(triggerGestureUpdate(_:)))
        self.navigationController.view.addGestureRecognizer(self.gesture)
        
        if let popGesture = self.navigationController.interactivePopGestureRecognizer
        {
            self.gesture.require(toFail: popGesture)
        }
    }
    
    private(set) var initialized = false, interactive = false
    @objc final func triggerGestureUpdate(_ sender:UIPanGestureRecognizer)
    {
        if (sender.state == .began && !interactive)
        {
            initialized = true
            if let popController = navigationController.popViewController(animated: true)
            {
                let position = sender.location(in: popController.view)
                let frame = popController.view.frame
                anchor.x = position.x / frame.width
                anchor.y = position.y / frame.height
            }
        }
    }
}

extension NavigationTransitionController : UIGestureRecognizerDelegate
{
    //MARK: subclass override
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool
    {
        if !interactive
        {
            let translation = gesture.translation(in: gesture.view)
            let vertical = translation.y > 0 && abs(translation.y) > abs(translation.x)
            return vertical && navigationController.viewControllers.count >= 2
        }
        
        return transitionContext.isInteractive
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    {
        return true
    }
}

extension NavigationTransitionController : UINavigationControllerDelegate
{
    func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationControllerOperation, from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning?
    {
        self.operation = operation
        return self
    }
    
    func navigationController(_ navigationController: UINavigationController, interactionControllerFor animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning?
    {
        return self
    }
    
    func navigationControllerPreferredInterfaceOrientationForPresentation(_ navigationController: UINavigationController) -> UIInterfaceOrientation
    {
        return .portrait
    }
    
    func navigationControllerSupportedInterfaceOrientations(_ navigationController: UINavigationController) -> UIInterfaceOrientationMask
    {
        return .all
    }
}

extension NavigationTransitionController : UIViewControllerAnimatedTransitioning
{
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval
    {
        return self.duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning)
    {
        
    }
    
    func animationEnded(_ transitionCompleted: Bool)
    {
        gesture.removeTarget(self, action: #selector(interactionGestureUpdate(_:)))
        transitionAnimator = nil
        transitionContext = nil
        initialized = false
        interactive = false
        print(#function)
    }
    
    func interruptibleAnimator(using transitionContext: UIViewControllerContextTransitioning) -> UIViewImplicitlyAnimating
    {
        return transitionAnimator
    }
}

extension NavigationTransitionController : UIViewControllerInteractiveTransitioning
{
    final func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning)
    {
        print(#function)
        
        interactive = true
        gesture.addTarget(self, action: #selector(interactionGestureUpdate(_:)))
        transitionAnimator = createTransitionAnimator(transitionContext: transitionContext)
        transitionAnimator.addCompletion
        { position in
            if position == .end
            {
                transitionContext.finishInteractiveTransition()
            }
            else
            {
                transitionContext.cancelInteractiveTransition()
            }
            transitionContext.completeTransition(position == .end)
        }
        
        self.transitionContext = transitionContext
        if !transitionContext.isInteractive
        {
            animate(to: .end)
        }
    }
    
    //MARK: subclass override
    func createTransitionAnimator(transitionContext:UIViewControllerContextTransitioning)->UIViewPropertyAnimator
    {
        let toController = transitionContext.viewController(forKey: .to)!
        
        let fromView = transitionContext.view(forKey: .from)!
        let toView = transitionContext.view(forKey: .to)!
        
        toView.frame = transitionContext.finalFrame(for: toController)
        toView.clipsToBounds = true
        
        let transitionAnimator:UIViewPropertyAnimator
        if operation == .push
        {
            toView.backgroundColor = .clear
            transitionContext.containerView.insertSubview(toView, aboveSubview: fromView)
            transitionAnimator = UIViewPropertyAnimator(duration: duration, curve: .linear)
            {
                toView.backgroundColor = .white
            }
        }
        else
        {
            transitionContext.containerView.insertSubview(toView, belowSubview: fromView)
            transitionAnimator = UIViewPropertyAnimator(duration: duration, curve: .linear)
            {
                fromView.backgroundColor = .clear
                fromView.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
                fromView.layer.cornerRadius = 20
                fromView.alpha = 0.5
            }
        }
        
        return transitionAnimator
    }
    
    func fraction(of translation:CGPoint)->CGFloat
    {
        return (operation == .push ? -1.0 : 1.0) * translation.y / transitionContext.containerView.bounds.midY * 2
    }
    
    func animate(to position:UIViewAnimatingPosition)
    {
        transitionAnimator.isReversed = position == .start
        if transitionAnimator.state == .inactive
        {
            transitionAnimator.startAnimation()
        }
        else
        {
            transitionAnimator.continueAnimation(withTimingParameters: nil, durationFactor: 0.0)
        }
    }
    
    @objc final func interactionGestureUpdate(_ sender:UIPanGestureRecognizer)
    {
        switch sender.state
        {
            case .began, .changed:
                let translation = sender.translation(in: transitionContext.containerView)
                interactionUpdate(with: translation)
                sender.setTranslation(CGPoint.zero, in: transitionContext.containerView)
            case .ended, .cancelled, .failed:
                gesture.removeTarget(self, action: #selector(interactionGestureUpdate(_:)))
                if transitionContext.isInteractive
                {
                    let position = completionAnimatingPosition()
                    if position == .start
                    {
                        restoreInteraction()
                    }
                    else
                    {
                        animate(to: position)
                    }
                }
            default:break
        }
    }
    
    //MARK: subclass override
    func interactionUpdate(with translation:CGPoint)
    {
        let percentComplete = clamp(transitionAnimator.fractionComplete + fraction(of: translation), 0, 1)
        transitionAnimator.fractionComplete = percentComplete
        transitionContext.updateInteractiveTransition(percentComplete)
        updateInteractiveTransition(percentComplete, with: translation)
    }
    
    //MARK: subclass override
    func updateInteractiveTransition(_ percentComplete:CGFloat, with translation:CGPoint)
    {
        let fromController = transitionContext.viewController(forKey: .from)!
        let touchOffset = gesture.location(in: transitionContext.containerView)
        let fromView = fromController.view!
        var frame = fromView.frame
        frame.origin.x = touchOffset.x - frame.width  * anchor.x
        frame.origin.y = touchOffset.y - frame.height * anchor.y
        fromView.frame = frame
    }
    
    //MARK: subclass override
    func restoreInteraction()
    {
        let view = transitionContext.view(forKey: .from)!
        let rect = transitionContext.containerView.frame
        let restoreAnimator = UIViewPropertyAnimator(duration: 0.2, curve: .linear)
        {
            view.frame.origin.x += rect.midX - view.frame.midX
            view.frame.origin.y += rect.midY - view.frame.midY
        }
        gesture.isEnabled = false
        restoreAnimator.addCompletion
        { [unowned self] _ in
            self.gesture.isEnabled = true
            self.animate(to: .start)
        }
        restoreAnimator.startAnimation()
    }
    
    func completionAnimatingPosition()->UIViewAnimatingPosition
    {
        let velocity = gesture.velocity(in: transitionContext.containerView)
        let flicking = sqrt(velocity.x * velocity.x + velocity.y * velocity.y) > 1200
        let down = flicking && velocity.y > 0
        let up = flicking && velocity.y < 0
        
        let position:UIViewAnimatingPosition
        if (operation == .pop && down) || (operation == .push && up)
        {
            position = .end
        }
        else if (operation == .pop && up) || (operation == .push && down)
        {
            position = .start
        }
        else if transitionAnimator.fractionComplete >= 0.33
        {
            position = .end
        }
        else
        {
            position = .start
        }
        
        return position
    }
    
    var wantsInteractiveStart: Bool
    {
        return initialized
    }
}
