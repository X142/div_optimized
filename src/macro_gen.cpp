#include <boost/multiprecision/cpp_int.hpp>
#include <boost/format.hpp>
#include <iostream>
#include <fstream>

namespace mp = boost::multiprecision;

int main()
{
	// �p�����[�^ -----------------------------------------------------------------------------------------------
	// p : 64bit ����
	//      >= cnt_in_div_set
	uint64_t p = std::pow(10, 16); // 10^16

	// DBG_cnt_div : ���Z���s��
	//							< 2^128
	mp::uint128_t DBG_cnt_div = (mp::uint128_t(0x0000000000000000) << 64) 
												  + mp::uint128_t(0x00000000000000ff);
	//mp::uint128_t DBG_cnt_div = ~mp::uint128_t(0);

	bool Cx_floor = 1;
	bool p_gt_2_to_the_power_of_63 = p > std::pow(2, 63) ? 1 : 0;

	// �萔 -----------------------------------------------------------------------------------------------
	// two_to_the_power_of_128 := 2^128
	//													129bit
	mp::uint256_t two_to_the_power_of_128 = mp::uint256_t(1) << 128;

	// M_128 := (2^128) - 1
	mp::uint128_t M_128 = ~mp::uint128_t(0);
	
	//  -----------------------------------------------------------------------------------------------
	// q_M_128_div_by_p := [M_128 / p]
	mp::uint128_t q_M_128_div_by_p = M_128 / p;
	// r_M_128_div_by_p := M_128 % p
	uint64_t  r_M_128_div_by_p = (uint64_t)(M_128 % p);

	// cnt_in_div_set : 1 ��̏��Z�Z�b�g�Ń`�F�b�N����_�̌�
	//						     := 4
	//							  n mod p = (p-1), k, 1, 0 (1 < k < p-1) �� 4 �_��z�肵�Ă���
	uint64_t pcs_check_points_in_div_set = 4;

	// pcs_endpoint : �[�_�̌�
	//							 := 2 // if r_M_128_div_by_p != 0 // M_128, (M_128 - r_M_128_div_by_p) �� 2 �_
	//							 := 1 // else // M_128 �� 1 �_
	unsigned short pcs_endpoint = r_M_128_div_by_p == 0 ? 1 : 2;

	// cnt_div_excluding_endpoint : �[�_���������Z���s��
	//												  := DBG_cnt_div - pcs_endpoint
	mp::uint128_t cnt_div_excluding_endpoint = DBG_cnt_div - pcs_endpoint;
	
	// cnt_div_set : ���s���鏜�Z�Z�b�g��
	//                    := [(cnt_div_excluding_endpoint-1)/cnt_in_div_set] + 1
	mp::uint128_t cnt_div_set = ((cnt_div_excluding_endpoint - 1) / pcs_check_points_in_div_set) + 1;
	
	// DBG_cnt_div_max -----------------------------------------------------------------------------------------------
	// DBG_cnt_div_max : ���Z���s�񐔂̍ő�l
	//								   := cnt_in_div_set * q_M_128_div_by_p + pcs_endpoint
	mp::uint128_t DBG_cnt_div_max = pcs_check_points_in_div_set * q_M_128_div_by_p + pcs_endpoint;

	// expected -----------------------------------------------------------------------------------------------
	mp::uint128_t expected_qutient = q_M_128_div_by_p;
	uint64_t expected_remainder = r_M_128_div_by_p;

	// Cx -----------------------------------------------------------------------------------------------
	// Cx_128_floor := [two_to_the_power_of_128 / p]
	//							   < 2^127 (p > 2)
	mp::uint128_t Cx_128_floor = (mp::uint128_t)(two_to_the_power_of_128 / p);

	// Cx_128_ceiling := Cx_128_floor + 1
	//								  < (2^127) + 1 (p > 2)
	mp::uint128_t Cx_128_ceiling = Cx_128_floor + 1;
	
	// diff_p_minus_1_to_k -----------------------------------------------------------------------------------------------
	uint64_t p_k, r_k;
	if (cnt_div_set <= (p - 1) - 2)
	{
		p_k = (uint64_t)(((p - 1) - 2) / cnt_div_set);
		r_k = (uint64_t)(((p - 1)- 2) % cnt_div_set);
	}
	else
	{
		p_k = 1;
		r_k = 0;
	}

	// k : [2, p-2] �����Z���s�񐔂ɏ]���ē��Ԋu�ɐi��
	//    = 2 + (p-1)-2 % cnt_div_set // if cnt_div_set <= (p-1)-2
	//	   = 2 // else
	uint64_t k = 2 + r_k;

	// increment_k : increment_k �̃f�N�������g�l
	// 												     := [((p-1)-2) / cnt_div_set] // if cnt_div_set <= (p-1)-2
	//													     := 1 // else
	uint64_t increment_k = p_k;
	
	// ����`�F�b�N -----------------------------------------------------------------------------------------------
	try
	{
		// p �̐���
		if (p < pcs_check_points_in_div_set)
		{
			throw "!! p �����������܂� : p < pcs_check_points_in_div_set";
		}
	}
	catch (char const* const err)
	{
		std::cerr << err << std::endl;
	}

	// DBG_cnt_div �̐���
	if (DBG_cnt_div > DBG_cnt_div_max)
	{
		DBG_cnt_div = DBG_cnt_div_max;
		std::cout << "�x��: " << "���Z���s�񐔂��ő�l�𒴂��Ă��܂� : DBG_cnt_div = DBG_cnt_div_max �ɐ�������܂���" << std::endl;
	}

	// �}�N������ -----------------------------------------------------------------------------------------------
	std::cout << "DBG_cnt_div_max_hi: " << boost::format("0x%016x") % (DBG_cnt_div_max >> 64) << std::endl;
	std::cout << "DBG_cnt_div_max_lo: " << boost::format("0x%016x") % (DBG_cnt_div_max & 0xffffffffffffffff) << std::endl;
	std::cout << std::endl;

	// �}�N������ -----------------------------------------------------------------------------------------------
	if (Cx_floor)
	{
		std::cout << "%define" << " " << "Cx_128_floor" << std::endl;
		std::cout << "%define" << " " << "m_Cx_128_hi" << " " << boost::format("0x%016x") % (Cx_128_floor >> 64) << std::endl;
		std::cout << "%define" << " " << "m_Cx_128_lo" << " " << boost::format("0x%016x") % (Cx_128_floor & 0xffffffffffffffff) << std::endl;
	}
	else
	{
		std::cout << "%define" << " " << "Cx_128_ceiling" << std::endl;
		std::cout << "%define" << " " << "m_Cx_128_hi" << " " << boost::format("0x%016x") % (Cx_128_ceiling >> 64) << std::endl;
		std::cout << "%define" << " " << "m_Cx_128_lo" << " " << boost::format("0x%016x") % (Cx_128_ceiling & 0xffffffffffffffff) << std::endl;
	}
	if (p_gt_2_to_the_power_of_63)
	{
		std::cout << "%define" << " " << "p_gt_2_to_the_power_of_63" << std::endl;
	}
	std::cout << "%define" << " " << "m_p" << " " << boost::format("0x%016x") % p << std::endl;
	
	std::cout << "%define" << " " << "m_pcs_check_points_in_div_set" << " " << pcs_check_points_in_div_set << std::endl;
	
	std::cout << "%define" << " " << "m_DBG_cnt_div_hi" << " " << boost::format("0x%016x") % (DBG_cnt_div >> 64) << std::endl;
	std::cout << "%define" << " " << "m_DBG_cnt_div_lo" << " " << boost::format("0x%016x") % (DBG_cnt_div & 0xffffffffffffffff) << std::endl;
	
	std::cout << "%define" << " " << "m_init_expected_qutient_hi" << " " << boost::format("0x%016x") % (expected_qutient >> 64) << std::endl;
	std::cout << "%define" << " " << "m_init_expected_qutient_lo" << " " << boost::format("0x%016x") % (expected_qutient & 0xffffffffffffffff) << std::endl;
	std::cout << "%define" << " " << "m_init_expected_remainder" << " " << boost::format("0x%016x") % expected_remainder << std::endl;
	std::cout << "%define" << " " << "m_init_k" << " " << boost::format("0x%016x") % k << std::endl;
	std::cout << "%define" << " " << "m_increment_k" << " " << boost::format("0x%016x") % increment_k << std::endl;

	return 0;
}

//734aca5f6226f0ada61
//105e6f4ddeffff


	// -----------------------------------------------------------------------------------------------
	//struct NASM_macro_info
	//{
	//	char const* const directive; // %define, %assign �Ȃ�
	//	char const* const identifier; // �}�N����
	//	char const* const token_string; // �u��������
	//};

	//std::vector<NASM_macro_info> vec_NASM_macro;

	//std::ofstream ofs_asm("plain_macro.asm");
	//if (ofs_asm.bad())
	//{
	//	std::cerr << "!! ofs_asm: �o�̓t�@�C���̃I�[�v���Ɏ��s���܂���" << std::endl;
	//	std::exit(1);
	//}

	//ofs_asm.close();
