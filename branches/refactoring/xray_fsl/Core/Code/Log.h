/*
������ ���� �������� ������ xrFSL
������:					Log
����������:				���������� ����������� �������.
�����:					Neo][
��������� ����������:	8.6.2008 by Neo][
ToDo:
*/	
#pragma once

/// �������, ������������ ������� ��������� � ����������� �� ����.
#define MP_INFO "** "
#define MP_NORMAL ""
#define MP_WARNING "[Warning] "
#define MP_ERROR "<<ERROR>> "

/// Log macros
#define LOG(msg) xrFSL::CLog::Instance().logMessage(msg)
#define LOGI(msg) xrFSL::CLog::Instance().logMessage(msg, xrFSL::CLog::MT_INFO)
#define LOGW(msg) xrFSL::CLog::Instance().logMessage(msg, xrFSL::CLog::MT_WARNING)
#define LOGE(msg) xrFSL::CLog::Instance().logMessage(msg, xrFSL::CLog::MT_ERROR)
#define LOGS xrFSL::CLog::Instance().stream()
#define LOGSI xrFSL::CLog::Instance().stream(xrFSL::CLog::MT_INFO)
#define LOGSW xrFSL::CLog::Instance().stream(xrFSL::CLog::MT_WARNING)
#define LOGSE xrFSL::CLog::Instance().stream(xrFSL::CLog::MT_ERROR)

#include "Prerequisites.h"
// C++ Stream stuff
#include <fstream>
#include <iostream>
#include <iomanip>
#include <sstream>

namespace xrFSL
{
	// forward decl
	class Stream;

	/**
	*	@brief ����� ������������ � ����.
	*/
	class xrFSL_CORE_API CLog
	{
	public:
		/// ���� ���������
		enum EMessageType
		{
			MT_INFO = 1,
			MT_NORMAL = 2,
			MT_WARNING = 3,
			MT_ERROR = 4
		};

		/**
		* ����������� �� ���������.
		* @param fileName - ��� ����� ����
		* @param debugOutput - ����������� �� ��������� � debug window
		*/
		CLog();
		/// ���������� �� ���������
		~CLog(void);

		static CLog& Instance();

		void Init(const char* pName);

		/**
		* @brief ������ ��������� � ����.
		* @param msg - ���������, ������� ����� ��������.
		* @param mt - ��� ���������. @see EMessageType
		* @param maskDebug - ���� true, ������ ��������� �� ����� �������� � debug window
		*/
		void logMessage(const String& msg, EMessageType mt = MT_NORMAL);

		/**
		*	
		*/
		Stream stream(EMessageType mt = MT_NORMAL);
	protected:
		std::ofstream m_fLogFile;	///< ���� ����
	};

	//=================================
	// Inline impl
	//=================================
	inline CLog& CLog::Instance()
	{
		static CLog instance0;
		return instance0;
	}


	/**
	*	
	*/
	class Stream
	{
	public:
		struct Flush {};

		Stream(CLog* pTarget, CLog::EMessageType mt)
			:m_pTarget(pTarget), m_eMT(mt)
		{

		}

		Stream(const Stream& rhs) 
			:m_pTarget(rhs.m_pTarget), m_eMT(rhs.m_eMT)
		{
			m_Cache.str(rhs.m_Cache.str());
		} 

		~Stream()
		{
			// flush on destroy
			if (m_Cache.tellp() > 0)
			{
				m_pTarget->logMessage(m_Cache.str(), m_eMT);
			}
		}

		template <typename T>
		Stream& operator<< (const T& v)
		{
			m_Cache << v;
			return *this;
		}

		Stream& operator<< (const Flush& v)
		{
			m_pTarget->logMessage(m_Cache.str(), m_eMT);
			m_Cache.str("");
			return *this;
		}
	protected:
		CLog* m_pTarget;
		CLog::EMessageType m_eMT;

		typedef std::ostringstream BaseStream;
		BaseStream m_Cache;
	private:
	};
}
