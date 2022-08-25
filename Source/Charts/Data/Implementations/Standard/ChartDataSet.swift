//
//  ChartDataSet.swift
//  Charts
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Algorithms
import Foundation

/// Determines how to round DataSet index values for `ChartDataSet.entryIndex(x, rounding)` when an exact x-value is not found.
@objc
public enum ChartDataSetRounding: Int
{
    case up = 0
    case down = 1
    case closest = 2
}

/// The DataSet class represents one group or type of entries (Entry) in the Chart that belong together.
/// It is designed to logically separate different groups of values inside the Chart (e.g. the values for a specific line in the LineChart, or the values of a specific group of bars in the BarChart).
open class ChartDataSet: ChartBaseDataSet
{
    public required init()
    {
        entries = []

        super.init()
    }

    override public convenience init(label: String)
    {
        self.init(entries: [], label: label)
    }

    @objc public init(entries: [ChartDataEntry], label: String)
    {
        self.entries = entries

        super.init(label: label)

        calcMinMax()
    }

    @objc public convenience init(entries: [ChartDataEntry])
    {
        self.init(entries: entries, label: "DataSet")
    }

    // MARK: - Data functions and accessors

    /// - Note: Calls `notifyDataSetChanged()` after setting a new value.
    /// - Returns: The array of y-values that this DataSet represents.
    /// the entries that this dataset represents / holds together
    @objc
    open private(set) var entries: [ChartDataEntry]

    /// Used to replace all entries of a data set while retaining styling properties.
    /// This is a separate method from a setter on `entries` to encourage usage
    /// of `Collection` conformances.
    ///
    /// - Parameter entries: new entries to replace existing entries in the dataset
    @objc
    public func replaceEntries(_ entries: [ChartDataEntry])
    {
        self.entries = entries
        notifyDataSetChanged()
    }

    /// maximum y-value in the value array
    internal var _yMax: Double = -Double.greatestFiniteMagnitude

    /// minimum y-value in the value array
    internal var _yMin: Double = .greatestFiniteMagnitude

    /// maximum x-value in the value array
    internal var _xMax: Double = -Double.greatestFiniteMagnitude

    /// minimum x-value in the value array
    internal var _xMin: Double = .greatestFiniteMagnitude

    override open func calcMinMax()
    {
        _yMax = -Double.greatestFiniteMagnitude
        _yMin = Double.greatestFiniteMagnitude
        _xMax = -Double.greatestFiniteMagnitude
        _xMin = Double.greatestFiniteMagnitude

        guard !isEmpty else { return }

        forEach(calcMinMax)
    }

    override open func calcMinMaxY(fromX: Double, toX: Double)
    {
        _yMax = -Double.greatestFiniteMagnitude
        _yMin = Double.greatestFiniteMagnitude

        guard !isEmpty else { return }

        var indexFrom = entryIndex(x: fromX, closestToY: .nan, rounding: .down)
        var indexTo = entryIndex(x: toX, closestToY: .nan, rounding: .up)
        // if indexFrom == -1 { indexFrom = 0 }
        // if indexTo == -1 { indexTo = entries.count - 1 }

        guard indexFrom != -1, indexTo != -1, indexTo >= indexFrom else { return }
        calcMinMaxY(fromX: fromX, toX: toX, entries: Array(entries[indexFrom ... indexTo]))
    }

    private func calcMinMaxY(fromX: Double, toX: Double, entries: [ChartDataEntry])
    {
        if entries.count == 1
        {
            let firstEntry = entries[0]
            if firstEntry.x < fromX || firstEntry.x > toX // , label == "data"
            {
                return
            }
        }

        var entries = Array(entries)

        let lastIndex = entries.count - 1
        if entries.count > 1, entries[0].x < fromX
        {
            let y = yValue(for: fromX, from: entries[0], and: entries[1])
            entries.remove(at: 0)
            entries.insert(ChartDataEntry(x: fromX, y: y), at: 0)
        }
        if entries.count > 1, entries[lastIndex].x > toX
        {
            let y = yValue(for: toX, from: entries[lastIndex - 1], and: entries[lastIndex])
            entries.remove(at: lastIndex)
            entries.insert(ChartDataEntry(x: toX, y: y), at: lastIndex)
        }

        for entry in entries
        {
            calcMinMaxY(entry: entry)
        }
    }

    private func yValue(for x: Double, from entryOne: ChartDataEntry, and entryTwo: ChartDataEntry) -> Double
    {
        let m = (entryTwo.y - entryOne.y) / (entryTwo.x - entryOne.x)
        let b = entryOne.y - (m * entryOne.x)
        return (m * x) + b
    }

    @objc open func calcMinMaxX(entry e: ChartDataEntry)
    {
        _xMin = Swift.min(e.x, _xMin)
        _xMax = Swift.max(e.x, _xMax)
    }

    @objc open func calcMinMaxY(entry e: ChartDataEntry)
    {
        _yMin = Swift.min(e.y, _yMin)
        _yMax = Swift.max(e.y, _yMax)
    }

    /// Updates the min and max x and y value of this DataSet based on the given Entry.
    ///
    /// - Parameters:
    ///   - e:
    internal func calcMinMax(entry e: ChartDataEntry)
    {
        calcMinMaxX(entry: e)
        calcMinMaxY(entry: e)
    }

    /// The minimum y-value this DataSet holds
    @objc override open var yMin: Double { return _yMin }

    /// The maximum y-value this DataSet holds
    @objc override open var yMax: Double { return _yMax }

    /// The minimum x-value this DataSet holds
    @objc override open var xMin: Double { return _xMin }

    /// The maximum x-value this DataSet holds
    @objc override open var xMax: Double { return _xMax }

    /// The number of y-values this DataSet represents
    @available(*, deprecated, message: "Use `count` instead")
    override open var entryCount: Int { return count }

    /// - Throws: out of bounds
    /// if `i` is out of bounds, it may throw an out-of-bounds exception
    /// - Returns: The entry object found at the given index (not x-value!)
    @available(*, deprecated, message: "Use `subscript(index:)` instead.")
    override open func entryForIndex(_ i: Int) -> ChartDataEntry?
    {
        guard indices.contains(i)
        else
        {
            return nil
        }
        return self[i]
    }

    /// - Parameters:
    ///   - xValue: the x-value
    ///   - closestToY: If there are multiple y-values for the specified x-value,
    ///   - rounding: determine whether to round up/down/closest if there is no Entry matching the provided x-value
    /// - Returns: The first Entry object found at the given x-value with binary search.
    /// If the no Entry at the specified x-value is found, this method returns the Entry at the closest x-value according to the rounding.
    /// nil if no Entry object at that x-value.
    override open func entryForXValue(
        _ xValue: Double,
        closestToY yValue: Double,
        rounding: ChartDataSetRounding) -> ChartDataEntry?
    {
        let index = entryIndex(x: xValue, closestToY: yValue, rounding: rounding)
        if index > -1
        {
            return self[index]
        }
        return entries.last
    }

    /// - Parameters:
    ///   - xValue: the x-value
    ///   - closestToY: If there are multiple y-values for the specified x-value,
    /// - Returns: The first Entry object found at the given x-value with binary search.
    /// If the no Entry at the specified x-value is found, this method returns the Entry at the closest x-value.
    /// nil if no Entry object at that x-value.
    override open func entryForXValue(
        _ xValue: Double,
        closestToY yValue: Double) -> ChartDataEntry?
    {
        return entryForXValue(xValue, closestToY: yValue, rounding: .closest)
    }

    /// - Returns: All Entry objects found at the given xIndex with binary search.
    /// An empty array if no Entry object at that index.
    override open func entriesForXValue(_ xValue: Double) -> [ChartDataEntry]
    {
        entries = entries.sorted { $0.x < $1.x }
        let partitioningIndex = partitioningIndex(where: { $0.x >= xValue })
        let startIndex = partitioningIndex > 1 ? partitioningIndex - 1 : 0
        return Array(entries[startIndex...].prefix(2))
    }

    /// - Parameters:
    ///   - xValue: x-value of the entry to search for
    ///   - closestToY: If there are multiple y-values for the specified x-value,
    ///   - rounding: Rounding method if exact value was not found
    /// - Returns: The array-index of the specified entry.
    /// If the no Entry at the specified x-value is found, this method returns the index of the Entry at the closest x-value according to the rounding.
    override open func entryIndex(
        x xValue: Double,
        closestToY yValue: Double,
        rounding: ChartDataSetRounding) -> Int
    {
        let nextClosestIndex = partitioningIndex { $0.x >= xValue }

        guard nextClosestIndex < endIndex else { return -1 }
        var closest = nextClosestIndex

        let prevClosestIndex = nextClosestIndex - 1

        if prevClosestIndex > startIndex
        {
            let nextXValueDistance = self[nextClosestIndex].x - xValue
            let prevXValueDistance = xValue - self[prevClosestIndex].x
            let closestXValueIndex = prevXValueDistance > nextXValueDistance ? nextClosestIndex : prevClosestIndex
            closest = closestXValueIndex
        }

        let closestXValue = self[closest].x

        switch rounding
        {
        case .up:
            // If rounding up, and found x-value is lower than specified x, and we can go upper...
            if closestXValue < xValue, closest < index(before: endIndex)
            {
                formIndex(after: &closest)
            }

        case .down:
            // If rounding down, and found x-value is upper than specified x, and we can go lower...
            if closestXValue > xValue, closest > startIndex
            {
                formIndex(before: &closest)
            }

        case .closest:
            break
        }

        // Search by closest to y-value
        if !yValue.isNaN
        {
            while closest > startIndex, self[index(before: closest)].x == closestXValue
            {
                formIndex(before: &closest)
            }

            var closestYValue = self[closest].y
            var closestYIndex = closest

            while closest < index(before: endIndex)
            {
                formIndex(after: &closest)
                let value = self[closest]

                if value.x != closestXValue { break }
                if abs(value.y - yValue) <= abs(closestYValue - yValue)
                {
                    closestYValue = yValue
                    closestYIndex = closest
                }
            }

            closest = closestYIndex
        }

        return closest
    }

    /// - Parameters:
    ///   - e: the entry to search for
    /// - Returns: The array-index of the specified entry
    // TODO: Should be returning `nil` to follow Swift convention
    @available(*, deprecated, message: "Use `firstIndex(of:)` or `lastIndex(of:)`")
    override open func entryIndex(entry e: ChartDataEntry) -> Int
    {
        return firstIndex(of: e) ?? -1
    }

    /// Adds an Entry to the DataSet dynamically.
    /// Entries are added to the end of the list.
    /// This will also recalculate the current minimum and maximum values of the DataSet and the value-sum.
    ///
    /// - Parameters:
    ///   - e: the entry to add
    /// - Returns: True
    // TODO: This should return `Void` to follow Swift convention
    @available(*, deprecated, message: "Use `append(_:)` instead", renamed: "append(_:)")
    override open func addEntry(_ e: ChartDataEntry) -> Bool
    {
        append(e)
        return true
    }

    /// Adds an Entry to the DataSet dynamically.
    /// Entries are added to their appropriate index respective to it's x-index.
    /// This will also recalculate the current minimum and maximum values of the DataSet and the value-sum.
    ///
    /// - Parameters:
    ///   - e: the entry to add
    /// - Returns: True
    // TODO: This should return `Void` to follow Swift convention
    override open func addEntryOrdered(_ e: ChartDataEntry) -> Bool
    {
        if let last = last, last.x > e.x
        {
            let startIndex = entryIndex(x: e.x, closestToY: e.y, rounding: .up)
            let closestIndex = self[startIndex...].lastIndex { $0.x < e.x }
                ?? startIndex
            calcMinMax(entry: e)
            entries.insert(e, at: closestIndex)
        }
        else
        {
            append(e)
        }

        return true
    }

    @available(*, renamed: "remove(_:)")
    override open func removeEntry(_ entry: ChartDataEntry) -> Bool
    {
        remove(entry)
    }

    /// Removes an Entry from the DataSet dynamically.
    /// This will also recalculate the current minimum and maximum values of the DataSet and the value-sum.
    ///
    /// - Parameters:
    ///   - entry: the entry to remove
    /// - Returns: `true` if the entry was removed successfully, else if the entry does not exist
    open func remove(_ entry: ChartDataEntry) -> Bool
    {
        guard let index = firstIndex(of: entry) else { return false }
        _ = remove(at: index)
        return true
    }

    /// Removes the first Entry (at index 0) of this DataSet from the entries array.
    ///
    /// - Returns: `true` if successful, `false` if not.
    // TODO: This should return the removed entry to follow Swift convention.
    @available(*, deprecated, message: "Use `func removeFirst() -> ChartDataEntry` instead.")
    override open func removeFirst() -> Bool
    {
        let entry: ChartDataEntry? = isEmpty ? nil : removeFirst()
        return entry != nil
    }

    /// Removes the last Entry (at index size-1) of this DataSet from the entries array.
    ///
    /// - Returns: `true` if successful, `false` if not.
    // TODO: This should return the removed entry to follow Swift convention.
    @available(*, deprecated, message: "Use `func removeLast() -> ChartDataEntry` instead.")
    override open func removeLast() -> Bool
    {
        let entry: ChartDataEntry? = isEmpty ? nil : removeLast()
        return entry != nil
    }

    /// Removes all values from this DataSet and recalculates min and max value.
    @available(*, deprecated, message: "Use `removeAll(keepingCapacity:)` instead.")
    override open func clear()
    {
        removeAll(keepingCapacity: true)
    }

    // MARK: - Data functions and accessors

    // MARK: - NSCopying

    override open func copy(with zone: NSZone? = nil) -> Any
    {
        let copy = super.copy(with: zone) as! ChartDataSet

        copy.entries = entries
        copy._yMax = _yMax
        copy._yMin = _yMin
        copy._xMax = _xMax
        copy._xMin = _xMin

        return copy
    }
}

// MARK: MutableCollection

extension ChartDataSet: MutableCollection
{
    public typealias Index = Int
    public typealias Element = ChartDataEntry

    public var startIndex: Index
    {
        return entries.startIndex
    }

    public var endIndex: Index
    {
        return entries.endIndex
    }

    public func index(after: Index) -> Index
    {
        return entries.index(after: after)
    }

    @objc
    public subscript(position: Index) -> Element
    {
        get
        {
            // This is intentionally not a safe subscript to mirror
            // the behaviour of the built in Swift Collection Types
            return entries[position]
        }
        set
        {
            calcMinMax(entry: newValue)
            entries[position] = newValue
        }
    }
}

// MARK: RandomAccessCollection

extension ChartDataSet: RandomAccessCollection
{
    public func index(before: Index) -> Index
    {
        return entries.index(before: before)
    }
}

// MARK: RangeReplaceableCollection

extension ChartDataSet: RangeReplaceableCollection
{
    public func append(_ newElement: Element)
    {
        calcMinMax(entry: newElement)
        entries.append(newElement)
    }

    public func remove(at position: Index) -> Element
    {
        let element = entries.remove(at: position)
        notifyDataSetChanged()
        return element
    }

    public func removeFirst() -> Element
    {
        let element = entries.removeFirst()
        notifyDataSetChanged()
        return element
    }

    public func removeFirst(_ n: Int)
    {
        entries.removeFirst(n)
        notifyDataSetChanged()
    }

    public func removeLast() -> Element
    {
        let element = entries.removeLast()
        notifyDataSetChanged()
        return element
    }

    public func removeLast(_ n: Int)
    {
        entries.removeLast(n)
        notifyDataSetChanged()
    }

    public func removeSubrange<R>(_ bounds: R) where R: RangeExpression, Index == R.Bound
    {
        entries.removeSubrange(bounds)
        notifyDataSetChanged()
    }

    @objc
    public func removeAll(keepingCapacity keepCapacity: Bool)
    {
        entries.removeAll(keepingCapacity: keepCapacity)
        notifyDataSetChanged()
    }
}
