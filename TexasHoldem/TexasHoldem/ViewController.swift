//
//  ViewController.swift
//  TexasHoldem
//
//  Created by larryhou on 6/3/2016.
//  Copyright © 2016 larryhou. All rights reserved.
//

import UIKit

class ViewModel {
    var data: [UniqueRound]
    var stats: [Int: [HandPattern: Int]]

    init(data: [UniqueRound], stats: [Int: [HandPattern: Int]]) {
        self.data = data
        self.stats = stats
    }

    init() {
        self.data = []
        self.stats = [:]
    }
}

class ViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var progressInfo: UILabel!
    @IBOutlet weak var progressIndicator: UIProgressView!

    @IBOutlet weak var peopleStepper: UIStepper!
    @IBOutlet weak var peopleInput: UITextField!

    @IBOutlet weak var roundStepper: UIStepper!
    @IBOutlet weak var roundInput: UITextField!

    @IBOutlet weak var simulateButton: UIButton!

    private let background_queue = DispatchQueue(label: "TexasHoldem.background.simulate", attributes: DispatchQueueAttributes.concurrent)
    private let model = ViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        print(HandV1HighCard.description)
        print(HandV2OnePair.description)
        print(HandV3TwoPair.description)
        print(HandV4TreeOfKind.description)
        print(HandV5Straight.description)
        print(HandV6Flush.description)
        print(HandV7FullHouse.description)
        print(HandV8FourOfKind.description)
        print(HandV9StraightFlush.description)
    }

    func generateGameRounds(_ roundCount: Int, personCount: Int) {
        var digitCount = 0
        var value = Double(roundCount)
        while value >= 1 {
            value /= 10
            digitCount += 1
        }

        background_queue.async {
            var stats: [Int: [HandPattern: Int]] = [:]
            var data: [UniqueRound] = []

            UIApplication.shared().isIdleTimerDisabled = true
            self.simulateButton.isUserInteractionEnabled = false

            let start = Date()
            for n in 0..<roundCount {
                let round = UniqueRound(index: n)
                data.append(round)

                let result = PokerDealer.deal(personCount)
                for i in 0..<result.count {
                    result[i].evaluate()
                    round.list.append(RawPokerHand(index: n, id: UInt8(i), data: result[i].rawValue))

                    let hand = result[i]
                    if stats[i] == nil {
                        stats[i] = [:]
                    }

                    if stats[i]?[hand.pattern] == nil {
                        stats[i]?[hand.pattern] = 0
                    }

                    stats[i]?[hand.pattern]? += 1
                }

                DispatchQueue.main.async {
                    self.updateProgressIndicator(n + 1, total: roundCount, digitCount: digitCount, elapse: Date().timeIntervalSince(start))
                }
            }

            UIApplication.shared().isIdleTimerDisabled = false
            self.simulateButton.isUserInteractionEnabled = true

            DispatchQueue.main.async {
                self.setViewModel(data, stats: stats)
            }
        }
    }

    func setViewModel(_ data: [UniqueRound], stats: [Int: [HandPattern: Int]]) {
        model.data = data
        model.stats = stats
    }

    func updateProgressIndicator(_ count: Int, total: Int, digitCount: Int, elapse: TimeInterval) {
        progressInfo.text = String(format: "%0\(digitCount)d/%d %5.2f%% %5.3fs", count, total, Double(count) * 100 / Double(total), elapse)
        progressIndicator.progress = Float(count)/Float(total)
    }

    @IBAction func simulate(_ sender: AnyObject) {
        let roundCount = roundInput.text != "" ? NSString(string: roundInput.text!).integerValue : Int(roundStepper.value)
        let personCount = peopleInput.text != "" ? NSString(string: peopleInput.text!).integerValue : Int(peopleStepper.value)

        generateGameRounds(roundCount, personCount: personCount)
    }

    // MARK: text input
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == peopleInput {
            var value = NSString(string: peopleInput.text!).doubleValue
            value = max(min(peopleStepper.maximumValue, value), peopleStepper.minimumValue)

            peopleInput.text = String(format: "%.0f", value)
            peopleStepper.value = value
        } else
        if textField == roundInput {
            var value = NSString(string: roundInput.text!).doubleValue
            value = max(min(roundStepper.maximumValue, value), roundStepper.minimumValue)

            roundInput.text = String(format: "%.0f", value)
            roundStepper.value = value
        }

        return true
    }

    @IBAction func setPeopleCount(_ sender: AnyObject) {
        if sender is UIStepper {
            peopleInput.text = String(format: "%.0f", peopleStepper.value)
        }
    }

    @IBAction func setRoundCount(_ sender: AnyObject) {
        if sender is UIStepper {
            roundInput.text = String(format: "%.0f", roundStepper.value)
        }
    }

    // MARK: segue
    override func prepare(for segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "player" {
            let dst = segue.destinationViewController as! PlayerTableViewController
            dst.model = model
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
