enum LinearAlgebra {
    /// Solves `a · x = b` by Gaussian elimination with partial pivoting.
    /// Returns nil if `a` is (numerically) singular. Intended for small systems.
    static func solve(_ a: [[Double]], _ b: [Double]) -> [Double]? {
        let n = b.count
        var m = a
        var rhs = b
        for col in 0..<n {
            guard let pivot = (col..<n).max(by: { abs(m[$0][col]) < abs(m[$1][col]) }),
                  abs(m[pivot][col]) > 1e-12
            else { return nil }
            m.swapAt(col, pivot)
            rhs.swapAt(col, pivot)
            for row in (col + 1)..<n {
                let factor = m[row][col] / m[col][col]
                guard factor != 0 else { continue }
                for k in col..<n { m[row][k] -= factor * m[col][k] }
                rhs[row] -= factor * rhs[col]
            }
        }
        var x = [Double](repeating: 0, count: n)
        for row in stride(from: n - 1, through: 0, by: -1) {
            var sum = rhs[row]
            for k in (row + 1)..<n { sum -= m[row][k] * x[k] }
            x[row] = sum / m[row][row]
        }
        return x
    }

    /// Minimizes the sum of squared residuals with Levenberg–Marquardt, using a
    /// forward-difference Jacobian. Intended for tens of parameters.
    static func levenbergMarquardt(
        _ initial: [Double],
        residuals: ([Double]) -> [Double],
        iterations: Int = 60
    ) -> [Double] {
        var p = initial
        var r = residuals(p)
        var cost = r.reduce(0) { $0 + $1 * $1 }
        var lambda = 1e-3
        let n = p.count

        for _ in 0..<iterations {
            // Jacobian columns.
            var jacobian: [[Double]] = []
            for i in 0..<n {
                var q = p
                let h = 1e-6 * max(1, abs(p[i]))
                q[i] += h
                jacobian.append(zip(residuals(q), r).map { ($0 - $1) / h })
            }
            var jtj = [[Double]](repeating: [Double](repeating: 0, count: n), count: n)
            var jtr = [Double](repeating: 0, count: n)
            for i in 0..<n {
                jtr[i] = zip(jacobian[i], r).reduce(0) { $0 + $1.0 * $1.1 }
                for j in i..<n {
                    let v = zip(jacobian[i], jacobian[j]).reduce(0) { $0 + $1.0 * $1.1 }
                    jtj[i][j] = v
                    jtj[j][i] = v
                }
            }

            var improved = false
            while lambda < 1e8 {
                var a = jtj
                for i in 0..<n { a[i][i] += lambda * max(jtj[i][i], 1e-9) }
                guard let step = solve(a, jtr.map { -$0 }) else { lambda *= 10; continue }
                let candidate = zip(p, step).map(+)
                let rc = residuals(candidate)
                let c = rc.reduce(0) { $0 + $1 * $1 }
                if c < cost {
                    let converged = (cost - c) < 1e-10 * cost
                    p = candidate
                    r = rc
                    cost = c
                    lambda = max(lambda / 10, 1e-9)
                    improved = !converged
                    break
                }
                lambda *= 10
            }
            if !improved { break }
        }
        return p
    }
}
