//
//  SolveClasses.swift
//  VisionSudoku
//
//  Created by Laurent Lefevre on 07/11/2021.
//

import Foundation


class solver {
    private var digitArray :[String] = ["1","2","3","4","5","6","7","8","9"]
    var delegate :solverDelegate?

    init () {
    }
    

    func validity (grid:[String]) -> Bool {
        guard grid.count==81 , grid[0] != "-1" , self.population(grid: grid)[0] != "-1" else {return false}

        var nCell :Int = 0
        for i in 0...80 {
            if grid[i].count == 1 {
                nCell+=1
            }
        }
        
        return nCell > 20
    }
    
    
    func gridStatus (pGrid:[String]) -> String {
        guard pGrid[0] != "-1" else {return "-1"}
 
        for i in 0...80 {
            if pGrid[i].count != 1 {
                return "pending"
            }
        }
        return "0"
    }

    
    
    func population (grid:[String]) -> [String] {
        var resultCases :[String] = [String](repeating: "", count: 81)
        var cleanCases :[String] = [String](repeating: "", count: 81)
        var digitSquare :[String] = [String](repeating: "", count: 9)

        // Init Data
        for i in 0...80 {
            if grid[i].count == 1 {
                cleanCases[i] = grid[i]
            } else {
                cleanCases[i] = ""
            }
        }

        // Get square population
        for iSquare in 0...8 {
            digitSquare[iSquare] = ""
            let ligne = Int(iSquare / 3) * 3
            let colonne = (iSquare % 3) * 3
            for icolonne in 0...2 {
                for iligne in 0...2 {
                    let index = (ligne + iligne) * 9 + colonne + icolonne
                    let valeurCell = cleanCases[index]
                    if valeurCell.count == 1 {
                        if digitSquare[iSquare].contains(valeurCell) {
                            resultCases[0] = "-1"
                            return resultCases
                        }
                        digitSquare[iSquare] += valeurCell
                    }
                }
            }
        }
        
        // Get line + squarre population
        for i in 0...80 {
            resultCases[i] = cleanCases[i]
            if cleanCases[i].count != 1 {
                let ligne = Int(i / 9)
                let colonne = i % 9
                let squarreIndex = Int(ligne / 3) * 3 + Int(colonne / 3)
                resultCases[i] = digitSquare[squarreIndex]
                var contentligne = ""
                var contentcolonne = ""
                for j in 0...8 {
                    let indexcolonne = ligne * 9 + j
                    if cleanCases[indexcolonne] != "" && contentcolonne.contains(cleanCases[indexcolonne]) {
                        resultCases[0] = "-1"
                        return resultCases
                    } else {
                        contentcolonne += cleanCases[indexcolonne]
                    }
                    if indexcolonne != i && cleanCases[indexcolonne] != "" && !resultCases[i].contains(cleanCases[indexcolonne]) {
                        resultCases[i] += cleanCases[indexcolonne]
                    }

                    let indexligne = colonne + 9 * j
                    if cleanCases[indexligne].count>0 && contentligne.contains(cleanCases[indexligne]) {
                        resultCases[0] = "-1"
                        return resultCases
                    } else {
                        contentligne += cleanCases[indexligne]
                    }

                    if indexligne != i && cleanCases[indexligne] != "" && !resultCases[i].contains(cleanCases[indexligne]) {
                        resultCases[i] += cleanCases[indexligne]
                    }
                }
            }
        }
        return resultCases
    }
    
    
    
    func possibilities (grid:[String]) -> [String] {
        guard self.gridStatus(pGrid: grid) != "0" else {return grid}
        
        // get population
        var grille = self.population(grid: grid)
        
        // retrieve the most populated
        var caseTemp = 0
        var scenariiTemp = ""
        for i in 0...80 {
            if grille[i].count >= grille[caseTemp].count {
                caseTemp = i
                scenariiTemp = ""
                digitArray.forEach { digit in
                    if !grille[i].contains(digit) {
                        scenariiTemp += digit
                    }
                }
            }
        }
        
        if scenariiTemp.count > 0 {
            var tempgrid = grille
            var lastgoodgrip = grille
            var resultgrid = grille
            var statusGrid = ""
            var i = 0
            repeat {
                let start = scenariiTemp.index(scenariiTemp.startIndex, offsetBy: i)
                let end = scenariiTemp.index(scenariiTemp.startIndex, offsetBy: i)
                let range = start...end
                tempgrid[caseTemp] = String(scenariiTemp[range])
                delegate?.processGrid (cells: tempgrid)
                resultgrid = self.possibilities(grid: tempgrid)
                statusGrid = self.gridStatus(pGrid: resultgrid)
                if statusGrid != "-1" {
                    lastgoodgrip = tempgrid
                }
                i += 1
            } while (i<scenariiTemp.count && statusGrid == "pending")
            if self.gridStatus(pGrid: resultgrid) == "0" {
                return resultgrid
            } else {
                grille = lastgoodgrip
            }
        } else {
            grille[0] = "-1"
        }
        return grille
    }
}

protocol solverDelegate {
    func processGrid (cells:[String])
}
