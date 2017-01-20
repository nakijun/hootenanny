/*
 * This file is part of Hootenanny.
 *
 * Hootenanny is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * --------------------------------------------------------------------
 *
 * The following copyright notices are generated automatically. If you
 * have a new notice to add, please use the format:
 * " * @copyright Copyright ..."
 * This will properly maintain the copyright information. DigitalGlobe
 * copyrights will be updated automatically.
 *
 * @copyright Copyright (C) 2015 DigitalGlobe (http://www.digitalglobe.com/)
 */

#ifndef ARFFREADER_H
#define ARFFREADER_H

// boost
#include <boost/iostreams/filtering_stream.hpp>

// hoot
#include <hoot/core/scoring/DataSamples.h>

// Qt
#include <QString>

// Standard
#include <fstream>
#include <map>
#include <memory>
#include <vector>

namespace hoot
{
using namespace std;

/**
 * @brief The ArffReader class
 * It is assumed that the input was generated by ArffWriter (and only ArffWriter). If you want to
 * use generic Arff files for input you'll need to do some rewriting.
 */
class ArffReader
{
public:

  /**
   * @brief ArffReader
   * @param strm Does not take ownership.
   */
  ArffReader(istream* strm);
  ArffReader(QString path);

  /**
   * @brief Reads data samples from the given input stream.
   */
  boost::shared_ptr<DataSamples> read();

private:
  auto_ptr<fstream> _autoStrm;
  auto_ptr<boost::iostreams::filtering_istream> _bstrm;
  istream* _strm;
  char _buffer[2048];

  bool _eof();
  QString _readLine();
};

}

#endif // ARFFREADER_H
