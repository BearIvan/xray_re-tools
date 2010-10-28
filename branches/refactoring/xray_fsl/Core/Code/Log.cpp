/*
������ ���� �������� ������ xrFSL
������:					Log
����������:				���������� ����������� �������.
�����:					Neo][
��������� ����������:	8.6.2008 by Neo][ - created
ToDo:
*/
#include "StdAfx.h"
#include "Log.h"

namespace xrFSL
{
	//-----------------------------------------------------------------------
	//
	//-----------------------------------------------------------------------
	CLog::CLog()
	{
		
	}

	//-----------------------------------------------------------------------
	//
	//-----------------------------------------------------------------------
	CLog::~CLog(void)
	{
		// ��������� ����
		m_fLogFile.close();
	}

	void CLog::Init( const char* pName )
	{
		// ������ ���� ����
		m_fLogFile.open(pName);
	}

	//-----------------------------------------------------------------------
	//
	//-----------------------------------------------------------------------
	void CLog::logMessage( const String& msg, EMessageType mt /*= LML_NORMAL*/)
	{
		//if ((m_eLogLevel + ml) >= LOG_THRESHOLD)
		//{
		// ������������� ������� ��� ���������
		String prefix;
		switch(mt)
		{
		case MT_WARNING:
			prefix = MP_WARNING;
			break;
		case MT_ERROR:
			prefix = MP_ERROR;
			break;
		case MT_NORMAL:
			prefix = MP_NORMAL;
			break;
		case MT_INFO:
			prefix = MP_INFO;
			break;
		default:
			prefix = "";
			break;
		}

		// �������� ��������� ���������
		// Neo][ -- ����� �������� ��� ������ �����, ������ ������
		/*struct tm* pTime;

		time_t Time;
		time(&Time);
		pTime = localtime(&Time);
		// ������ ��������� � ���� � �����������

		m_fLogFile << std::setw(2) << std::setfill('0') << pTime->tm_hour
		<< ":" << std::setw(2) << std::setfill('0') << pTime->tm_min
		<< ":" << std::setw(2) << std::setfill('0') << pTime->tm_sec 
		<< ":" << prefix << msg << std::endl;*/
		m_fLogFile << prefix << msg << std::endl;


		// ��������� ����� � ����
		m_fLogFile.flush();
		//}
	}

	//-----------------------------------------------------------------------
	//
	//-----------------------------------------------------------------------
	Stream CLog::stream( EMessageType mt /*= MT_NORMAL*/)
	{
		return Stream(this, mt);
	}
}