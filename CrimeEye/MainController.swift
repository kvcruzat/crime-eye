//
//  ViewController.swift
//  CrimeEye
//
//  Created by Gurpreet Paul on 21/11/2015.
//  Copyright © 2015 Gurpreet Paul. All rights reserved.
//

import UIKit
import Siesta
import SwiftyJSON
import MMDrawerController
import Charts

class MainController: UIViewController, ResourceObserver {
    
    var date: String = ""
    var monthArray = [String]()
    
    let statusOverlay = ResourceStatusOverlay()
    
    typealias CrimeDict = Dictionary<String, AnyObject>
    var crimesArray: [CrimeDict] = []
    
    var outcomesDict = [String:[String]]()
    
    // MARK: Outlets
    @IBOutlet weak var nCrimes: UILabel!
    @IBOutlet weak var topCrimes: UILabel!
    @IBOutlet weak var resolvedCrimes: UILabel!
    @IBOutlet weak var pieChartView: PieChartView!
    @IBOutlet weak var lineChartView: LineChartView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        statusOverlay.embedIn(self)
        loadData()
        // Do any additional setup after loading the view, typically from a nib.
        
        view.backgroundColor = Style.viewBackground
        nCrimes.textColor = Style.flatGold2
        resolvedCrimes.textColor = Style.flatGold2
        topCrimes.textColor = Style.flatGold2
    }
    
    func loadData() {
        let lat = PostcodesAPI.lat
        let lng = PostcodesAPI.lng
        self.date = String(PoliceAPI.lastUpdated.characters.dropLast(3))
        if (lat == 0.0){
            PostcodesAPI.postcodeToLatAndLng("LS2 9JT").addObserver(owner: self) {
                resource, event in
                if case .NewData = event {
                    let result = resource.json["result"]
                    PostcodesAPI.lat = result["latitude"].doubleValue
                    PostcodesAPI.lng = result["longitude"].doubleValue
                    
                    PoliceAPI.getLastUpdated().addObserver(owner: self) {
                            resource2, event in
                            PoliceAPI.lastUpdated = resource2.json["date"].stringValue
            
                            self.date = PoliceAPI.getYearAndMonth(PoliceAPI.lastUpdated)
                        
                            self.loadData()
                        
                    }.addObserver(self.statusOverlay).loadIfNeeded()
                    
                }
                }.addObserver(statusOverlay).loadIfNeeded()
        }
        else if (self.date.characters.count == 7 && monthArray.isEmpty) {
                loadOutcomes( lat, lng: lng)
        }
        else{
        }
        
    }
    
    func loadOutcomes(lat: Double, lng: Double){
        let dateArr = self.date.componentsSeparatedByString("-")
        let year = dateArr[0]
        let month = dateArr[1]
        
        let date1 = previousMonths(5, year: year, month: month)
        let date2 = previousMonths(4, year: year, month: month)
        let date3 = previousMonths(3, year: year, month: month)
        let date4 = previousMonths(2, year: year, month: month)
        let date5 = previousMonths(1, year: year, month: month)
        let date6 = self.date
        
        monthArray = [date1, date2, date3, date4, date5, date6]
        
        var i = 0;
        for monthDate in monthArray{
            PoliceAPI.getOutcomes(monthDate, lat: lat, long: lng).addObserver(owner: self) {
                resource, event in
                let outResults = resource.json
                
                var outArray = [String]()
                
                for (_, outcome) in outResults {
                    outArray.append(outcome["category"]["code"].stringValue)
                }
                self.outcomesDict[monthDate] = outArray
                if (i == self.monthArray.count) {
                    PoliceAPI
                        .getCrimes(lat, long: lng)
                        .addObserver(self)
                        .addObserver(self.statusOverlay)
                        .load()
                }
                
                
            }.addObserver(self.statusOverlay).load()
            ++i
        }
        
        
    }
    
    func resourceChanged(resource: Resource, event: ResourceEvent) {
        crimesArray = []
        
        // If we have some new data
        if (resource.latestData != nil) {
            let jsonArray = resource.json
            
            // iterate over all the crimes
            for (_, crimes) in jsonArray {
                
                let month       = crimes["month"].stringValue
                let cat         = crimes["category"].stringValue

                // store information on each crime
                let crimeDict = self.crimeToDict(month,
                    category: cat)
                
                self.crimesArray.append(crimeDict)
                
            }
            nCrimes.text = String(self.crimesArray.count)
            loadStatistics()
            resource.removeObservers(ownedBy: self)
        }
    }
    
    internal func crimeToDict(month: String,
            category: String) -> CrimeDict {
            
            var crimeDict = [String: AnyObject]()
            crimeDict["month"]       = month
            crimeDict["category"]    = category
                
            return crimeDict
    }
    
    internal func previousMonths(monthsToDeduct: Int, year: String, month: String)-> String {
        var yearNum = Int(year)!
        var monthNum = Int(month)!
        
        if (monthNum - monthsToDeduct < 1){
            --yearNum
            monthNum = (monthNum - monthsToDeduct) % 12
        }
        else {
            monthNum = monthNum - monthsToDeduct
        }
        
        return "\(yearNum)-\(monthNum)"
    }
    
    func loadStatistics(){
        var catDict = [String: Double]()
        for crime in crimesArray{
            if (catDict[String(crime["category"]!)] == nil){
                catDict[String(crime["category"]!)] = 1
            }
            else {
                catDict[String(crime["category"]!)]! += 1
            }
        }
        let sortedCat = catDict.keys.sort({ (firstKey, secondKey) -> Bool in
            return catDict[firstKey] > catDict[secondKey]
        })

        var topCatArray = [String]()
        if ( sortedCat.count > 3){
            topCatArray += sortedCat[0..<3]
        }
        else {
            topCatArray += sortedCat[0..<sortedCat.count]
        }
        var dataEntries: [ChartDataEntry] = []
        
        for var i = 0; i < topCatArray.count; ++i {
            let dataEntry = ChartDataEntry(value: catDict[sortedCat[i]]!, xIndex: i)
            dataEntries.append(dataEntry)
        }
        
        let pieChartDataSet = PieChartDataSet(yVals: dataEntries, label: "")
        let pieChartData = PieChartData(xVals: topCatArray, dataSet: pieChartDataSet)
        
        var colors: [UIColor] = []
        
        colors = [Style.flatRed1, Style.white, Style.flatGold2]
        
        pieChartDataSet.colors = colors
        
        pieChartView.data = pieChartData
        pieChartData.setDrawValues(false)
        pieChartView.drawSliceTextEnabled = false
        pieChartView.holeColor = Style.viewBackground
        pieChartView.rotationWithTwoFingers = true
        pieChartView.animate(xAxisDuration: NSTimeInterval(5))
        pieChartView.legend.position = .RightOfChart
        pieChartView.legend.textColor = Style.white
        pieChartView.descriptionText = ""
        pieChartView.backgroundColor = Style.viewBackground
        
        
        
        var numResolvedArr: [ChartDataEntry] = []
        
        var i = 0
        for month in monthArray {
            let dataEntry = ChartDataEntry(value: Double(outcomesDict[month]!.count), xIndex: i)
            numResolvedArr.append(dataEntry)
            ++i
        }
        
        let lineChartDataSet = LineChartDataSet(yVals: numResolvedArr)
        let lineChartData = LineChartData(xVals: monthArray, dataSet: lineChartDataSet)
        lineChartDataSet.circleColors = [Style.flatGold2]
        lineChartDataSet.circleHoleColor = Style.white
        lineChartView.leftAxis.startAtZeroEnabled = false
        lineChartData.setDrawValues(false)
        lineChartView.data = lineChartData
        lineChartView.legend.enabled = false
        lineChartView.descriptionText = ""
        lineChartView.rightAxis.enabled = false
        lineChartView.xAxis.labelPosition = .Bottom
        lineChartView.leftAxis.xOffset = 9.0
        lineChartView.xAxis.labelTextColor = Style.white
        lineChartView.xAxis.avoidFirstLastClippingEnabled = true
        lineChartView.leftAxis.labelTextColor = Style.white
        lineChartView.animate(xAxisDuration: NSTimeInterval(4))
        lineChartView.backgroundColor = Style.viewBackground
        lineChartView.gridBackgroundColor = Style.viewBackground
        lineChartView.xAxis.drawGridLinesEnabled = false
        lineChartView.leftAxis.drawGridLinesEnabled = false
        lineChartView.xAxis.axisLineColor = Style.white
        lineChartView.leftAxis.axisLineColor = Style.white


    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func openDrawer(sender: UIBarButtonItem) {
        let appDelegate:AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.centerContainer!.toggleDrawerSide(MMDrawerSide.Left, animated: true, completion: nil)
    }

}

