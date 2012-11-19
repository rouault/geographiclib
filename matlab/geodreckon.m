function [lat2, lon2, azi2, S12, m12, M12, M21, a12] = ...
      geodreckon(lat1, lon1, s12, azi1, ellipsoid, arcmode)
%GEODRECKON  Point at specified azimuth, range on an ellipsoid
%
%   [lat2, lon2, azi2] = GEODRECKON(lat1, lon1, s12, azi1)
%   [lat2, lon2, azi2, S12, m12, M12, M21, a12] =
%     GEODRECKON(lat1, lon1, s12, azi1, ellipsoid, arcmode)
%
%   solves the direct geodesic problem of finding the final point and
%   azimuth given lat1, lon1, s12, and azi1.  The input arguments lat1,
%   lon1, s12, azi1, can be scalars or arrays of equal size.  lat1, lon1,
%   azi1 are given in degrees and s12 in meters.  The ellipsoid vector is
%   of the form [a, e], where a is the equatorial radius in meters, e is
%   the eccentricity.  If ellipsoid is omitted, the WGS84 ellipsoid is
%   used.  lat2, lon2, and azi2 give the position and forward azimuths at
%   the end point in degrees.  The other outputs, S12, m12, M12, M21, a12
%   are documented in GEODDOC.  GEODDOC also gives the restrictions on the
%   allowed ranges of the arguments.
%
%   If arcmode is true (default is false), then the input argument s12 is
%   interpreted as the arc length on the auxiliary sphere (in degrees) and
%   the corresponding distance is returned in the final output variable a12
%   (in meters).  The two optional arguments, ellispoid and arcmode, may be
%   given in any order and either or both may be omitted.
%
%   When given a combination of scalar and array inputs, GEODRECKON behaves
%   as though the inputs were expanded to match the size of the arrays.
%   However, in the particular case where LAT1 and AZI1 are the same for
%   all the input points, they should be specified as scalars since this
%   will considerably speed up the calculations.  (In particular a series
%   of points along a single geodesic is efficiently computed by specifying
%   an array for S12 only.)
%
%   This is an implementation of the algorithm given in
%
%     C. F. F. Karney
%     Algorithms for geodesics
%     J. Geodesy (2012)
%     http://dx.doi.org/10.1007/s00190-012-0578-z
%
%   This function duplicates some of the functionality of the RECKON
%   function in the MATLAB mapping toolbox.  Differences are
%
%     * When the ellipsoid argument is omitted, use the WGS84 ellipsoid.
%     * The azimuth at the end point azi2 is returned.
%     * The solution is accurate to round-off error.
%     * The algorithm is non-iterative and thus may be faster.
%     * Redundant calculations are avoided when computing multiple
%       points on a single geodesic.
%     * Additional properties of the geodesic are calcuated.
%
%   See also GEODDOC, GEODDISTANCE, GEODAREA, GEODESICDIRECT, GEODESICLINE.

% Copyright (c) Charles Karney (2012) <charles@karney.com> and licensed
% under the MIT/X11 License.  For more information, see
% http://geographiclib.sourceforge.net/
%
% This file was distributed with GeographicLib 1.27.
%
% This is a straightforward transcription of the C++ implementation in
% GeographicLib and the C++ source should be consulted for additional
% documentation.  This is a vector implementation and the results returned
% with array arguments are identical to those obtained with multiple calls
% with scalar arguments.

  try
    S = size(lat1 + lon1 + s12 + azi1);
  catch err
    error('lat1, lon1, s12, azi1 have incompatible sizes')
  end

  degree = pi/180;
  tiny = sqrt(realmin);

  if nargin <= 4
    ellipsoid = defaultellipsoid; arcmode = false;
  elseif nargin == 5
    arg5 = ellipsoid(:);
    if length(arg5) == 2
      ellipsoid = arg5; arcmode = false;
    else
      arcmode = arg5; ellipsoid = defaultellipsoid;
    end
  else
    arg5 = ellipsoid(:);
    arg6 = arcmode;
    if length(arg5) == 2
      ellipsoid = arg5; arcmode = arg6;
    else
      arcmode = arg5; ellipsoid = arg6;
    end
  end

  if length(ellipsoid) ~= 2
    error('ellipsoid must be a vector of size 2')
  end
  if ~isscalar(arcmode)
    error('arcmode must be true or false')
  end

  a = ellipsoid(1);
  e2 = ellipsoid(2)^2;
  f = e2 / (1 + sqrt(1 - e2));
  f1 = 1 - f;
  ep2 = e2 / (1 - e2);
  n = f / (2 - f);
  b = a * f1;

  areap = nargout >= 4;
  redlp = nargout >= 5;
  scalp = nargout >= 6;

  A3x = A3coeff(n);
  C3x = C3coeff(n);

  lat1 = lat1(:);
  lon1 = AngNormalize(lon1(:));
  azi1 = AngNormalize(azi1(:));
  s12 = s12(:);

  p = lat1 == 90;
  lon1(p) = lon1(p) + ((lon1(p) < 1) * 2 - 1) * 180;
  lon1(p) = AngNormalize(lon1(p) - azi1(p));
  azi1(p) = -180;

  p = lat1 == -90;
  lon1(p) = AngNormalize(lon1(p) + azi1(p));
  azi1(p) = 0;

  azi1 = AngRound(azi1);

  alp1 = azi1 * degree;
  salp1 = sin(alp1); salp1(azi1 == -180) = 0;
  calp1 = cos(alp1); calp1(abs(azi1) == 90) = 0;
  phi = lat1 * degree;
  sbet1 = f1 * sin(phi);
  cbet1 = cos(phi); cbet1(abs(lat1) == 90) = tiny;
  [sbet1, cbet1] = SinCosNorm(sbet1, cbet1);
  dn1 = sqrt(1 + ep2 * sbet1.^2);

  salp0 = salp1 .* cbet1; calp0 = hypot(calp1, salp1 .* sbet1);
  ssig1 = sbet1; somg1 = salp0 .* sbet1;
  csig1 = cbet1 .* calp1; csig1(sbet1 == 0 & calp1 == 0) = 1; comg1 = csig1;
  [ssig1, csig1] = SinCosNorm(ssig1, csig1);

  k2 = calp0.^2 * ep2;
  epsi = k2 ./ (2 * (1 + sqrt(1 + k2)) + k2);
  A1m1 = A1m1f(epsi);
  C1a = C1f(epsi);
  B11 = SinCosSeries(true, ssig1, csig1, C1a);
  s = sin(B11); c = cos(B11);
  stau1 = ssig1 .* c + csig1 .* s; ctau1 = csig1 .* c - ssig1 .* s;

  C1pa = C1pf(epsi);
  C3a = C3f(epsi, C3x);
  A3c = -f * salp0 .* A3f(epsi, A3x);
  B31 = SinCosSeries(true, ssig1, csig1, C3a);

  if arcmode
    sig12 = s12 * degree;
    ssig12 = sin(sig12);
    csig12 = cos(sig12);
    s12a = abs(s12);
    s12a = s12a - 180 * floor(s12a / 180);
    ssig12(s12a == 0) = 0;
    csig12(s12a == 90) = 0;
  else
    tau12 = s12 ./ (b * (1 + A1m1));
    s = sin(tau12); c = cos(tau12);
    B12 = - SinCosSeries(true,  stau1 .* c + ctau1 .* s, ...
                         ctau1 .* c - stau1 .* s, C1pa);
    sig12 = tau12 - (B12 - B11);
    ssig12 = sin(sig12); csig12 = cos(sig12);
    if abs(f) > 0.01
      ssig2 = ssig1 .* csig12 + csig1 .* ssig12;
      csig2 = csig1 .* csig12 - ssig1 .* ssig12;
      B12 =  SinCosSeries(true, ssig2, csig2, C1a);
      serr = (1 + A1m1) .* (sig12 + (B12 - B11)) - s12/b;
      sig12 = sig12 - serr ./ sqrt(1 + k2 .* ssig2.^2);
      ssig12 = sin(sig12); csig12 = cos(sig12);
    end
  end

  ssig2 = ssig1 .* csig12 + csig1 .* ssig12;
  csig2 = csig1 .* csig12 - ssig1 .* ssig12;
  dn2 = sqrt(1 + k2 .* ssig2.^2);
  if arcmode || redlp || scalp
    if arcmode || abs(f) > 0.01
      B12 = SinCosSeries(true, ssig2, csig2, C1a);
    end
    AB1 = (1 + A1m1) .* (B12 - B11);
  end
  sbet2 = calp0 .* ssig2;
  cbet2 = hypot(salp0, calp0 .* csig2);
  cbet2(cbet2 == 0) = tiny;
  somg2 = salp0 .* ssig2; comg2 = csig2;
  salp2 = salp0; calp2 = calp0 .* csig2;
  omg12 = atan2(somg2 .* comg1 - comg2 .* somg1, ...
                comg2 .* comg1 + somg2 .* somg1);
  lam12 = omg12 + ...
          A3c .* ( sig12 + (SinCosSeries(true, ssig2, csig2, C3a) - B31));
  lon12 = lam12 / degree;
  lon12 = AngNormalize2(lon12);
  lon2 = AngNormalize(lon1 + lon12);
  lat2 = atan2(sbet2, f1 * cbet2) / degree;
  azi2 = 0 - atan2(-salp2, calp2) / degree;
  if arcmode
    a12 = b * ((1 + A1m1) .* sig12 + AB1);
  else
    a12 = sig12 / degree;
  end

  if redlp || scalp
    A2m1 = A2m1f(epsi);
    C2a = C2f(epsi);
    B21 = SinCosSeries(true, ssig1, csig1, C2a);
    B22 = SinCosSeries(true, ssig2, csig2, C2a);
    AB2 = (1 + A2m1) .* (B22 - B21);
    J12 = (A1m1 - A2m1) .* sig12 + (AB1 - AB2);
    if redlp
      m12 = b * ((dn2 .* (csig1 .* ssig2) - dn1 .* (ssig1 .* csig2)) ...
                 - csig1 .* csig2 .* J12);
      m12 = reshape(m12, S);
    end
    if scalp
      t = k2 .* (ssig2 - ssig1) .* (ssig2 + ssig1) ./ (dn1 + dn2);
      M12 = csig12 + (t .* ssig2 - csig2 .* J12) .* ssig1 ./ dn1;
      M21 = csig12 - (t .* ssig1 - csig1 .* J12) .* ssig2 ./  dn2;
      M12 = reshape(M12, S); M21 = reshape(M21, S);
    end
  end

  if areap
    C4x = C4coeff(n);
    C4a = C4f(eps, C4x);
    A4 = (a^2 * e2) * calp0 .* salp0;
    B41 = SinCosSeries(false, ssig1, csig1, C4a);
    B42 = SinCosSeries(false, ssig2, csig2, C4a);
    salp12 = calp0 .* salp0 .* ...
             cvmgt(csig1 .* (1 - csig12) + ssig12 .* ssig1, ...
                   ssig12 .* (csig1 .* ssig12 ./ (1 + csig12) + ssig1), ...
                   csig12 <= 0);
    calp12 = salp0.^2 + calp0.^2 .* csig1 .* csig2;
    s = calp0 == 0 | salp0 == 0;
    salp12(s) = salp2(s) .* calp1(s) - calp2(s) .* salp1(s);
    calp12(s) = calp2(s) .* calp1(s) + salp2(s) .* salp1(s);
    s = s & salp12 == 0 & calp12 < 0;
    salp12(s) = tiny * calp1(s); calp12(s) = -1;
    if e2 == 0
      c2 = a^2;
    elseif e2 > 0
      c2 = (a^2 + b^2 * atanh(sqrt(e2))/sqrt(e2)) / 2;
    else
      c2 = (a^2 + b^2 * atan(sqrt(-e2))/sqrt(-e2)) / 2;
    end
    S12 = c2 * atan2(salp12, calp12) + A4 .* (B42 - B41);
  end

  lat2 = reshape(lat2, S);
  lon2 = reshape(lon2, S);
  azi2 = reshape(azi2, S);

end