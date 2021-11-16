#ifndef STFU_GLOBAL_H
#define STFU_GLOBAL_H

#include <QtCore/qglobal.h>

#if defined(STFU_LIBRARY)
#  define STFUSHARED_EXPORT Q_DECL_EXPORT
#else
#  define STFUSHARED_EXPORT Q_DECL_IMPORT
#endif

#endif // STFU_GLOBAL_H
