// Example of using the GeographicLib::AuxLatitude class.  See the paper
//
// - C. F. F. Karney,
//   On auxiliary latitudes,
//   Technical Report, SRI International, December 2022.
//   https://arxiv.org/abs/2212.05818

#include <iostream>
#include <iomanip>
#include <exception>
#include <GeographicLib/Utility.hpp>
#include <GeographicLib/AuxLatitude.hpp>

int main(int argc, const char* const argv[]) {
  try {
    typedef GeographicLib::AuxLatitude<double> latitude;
    typedef latitude::angle angle;
    if (argc != 3) {
      std::cerr << "Usage: example-AuxLatitude <n> <base-lat>\n";
      return 1;
    }
    double n = GeographicLib::Utility::fract<double>(std::string(argv[1]));
    int auxin = GeographicLib::Utility::val<int>(std::string(argv[2]));
    double a = 1+n, b = 1-n;    // Equatorial radius and polar semi-axis
    latitude aux(a, b);
    bool series = false;        // Don't use series method
    std::cout << std::setprecision(9) << std::fixed;
    int m = 1;
    for (int l = 0; l < 90*m; ++l) {
      angle phi(angle::degrees((l+0.5)/m));
      for (int auxout = 0; auxout < latitude::AUXNUMBER; ++auxout) {
        angle eta = aux.Convert(auxin, auxout, phi, series);
        std::cout << (auxout ? " " : "") << eta.degrees();
      }
      std::cout << "\n";
    }
  }
  catch (const std::exception& e) {
    std::cerr << "Caught exception: " << e.what() << "\n";
    return 1;
  }
}
