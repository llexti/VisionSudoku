//
//  SolveViewController.swift
//  VisionSudoku
//
//  Created by Laurent Lefevre on 06/11/2021.
//

import UIKit

class SolveViewController: UIViewController {
    @IBOutlet weak var sudokuImage: UIImageView!
    
    private var initialGrid :[Int:GridElement]?
    private var cells: [String] = []
    private var solvedGrid :[[String]] = []
    private var updateTimer :Timer?
    private var imageId :Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func initVC (_ grid :[Int:GridElement]) {
        self.cells.removeAll()
        self.initialGrid = grid
        for i in 0...80 {
            self.cells.append(self.initialGrid![i]!.value)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let toImage = gridImage(grid: self.cells, size: self.sudokuImage.frame.size).draw()
        UIView.transition(with: self.sudokuImage,
                          duration: 0.2,
                          options: .transitionCrossDissolve,
                          animations: { self.sudokuImage.image = toImage },
                          completion: {_ in self.solveButton(self)})
        

    }
    
    @IBAction func solveButton(_ sender: Any) {
        self.solvedGrid.removeAll()
        let solver = solver ()
        solver.delegate = self
        _ = solver.possibilities(grid: cells)
        self.imageId = 0
        self.updateTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.imageId += 1
            if self?.imageId == self?.solvedGrid.count {
                self?.updateTimer?.invalidate()
            } else {
                let toImage = gridImage(grid: (self?.solvedGrid[self!.imageId])!, size: self!.sudokuImage.frame.size).draw()
                UIView.transition(with: (self?.sudokuImage)!,
                                  duration: 0.1,
                                  options: .transitionCrossDissolve,
                                  //animations: { self?.sudokuImage.image = self?.solveImage[self!.imageId] },
                                  animations: { self?.sudokuImage.image = toImage },
                                  completion: nil)
            }

        }


    }


}

extension SolveViewController :solverDelegate {
    func processGrid(cells: [String]) {
        self.solvedGrid.append(cells)
    }
}
