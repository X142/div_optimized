#include <boost/multiprecision/cpp_int.hpp>
#include <boost/format.hpp>
#include <iostream>
#include <fstream>

namespace mp = boost::multiprecision;

int main()
{
	mp::uint128_t N = mp::pow(mp::uint128_t(2), 64);
	uint64_t P = std::pow(10, 16);
	std::cout << std::hex <<  N / P << std::endl;
	std::cout << std::hex <<  N % P << std::endl;

	// 定数 -----------------------------------------------------------------------------------------------
	// two_to_the_power_of_128 := 2^128
	//													129bit
	mp::uint256_t two_to_the_power_of_128 = mp::uint256_t(1) << 128;

	// M_128 := (2^128) - 1
	mp::uint128_t M_128 = ~mp::uint128_t(0);

	// cnt_in_div_set : 1 回の除算セットでチェックする点の個数
	//						     := 4
	//							  n mod p = (p-1), k, 1, 0 (1 < k < p-1) の 4 点を想定している
	uint64_t pcs_check_points_in_div_set = 4;

	// パラメータ -----------------------------------------------------------------------------------------------
	// p : 64bit 除数
	//      >= cnt_in_div_set
	uint64_t p = std::pow(10, 16); // 10^16
	{
		// p の制約
		if (p < pcs_check_points_in_div_set || ! (p & (p - 1)) || p == 0)
		{
			std::cerr <<  "!! p が小さすぎる または 2 の冪乗の形 または 0 : p < pcs_check_points_in_div_set || ! (p & (p - 1)) || p == 0" << std::endl;
			return 1;
		}
	}

	bool q_le_64bit = 1;
	bool div_optimized;
	mp::uint128_t n;
	if (q_le_64bit)
	{
		div_optimized = 1;
		// n = 2^(64+[log_2(p)])
		n = mp::pow(mp::uint128_t(2), 64 + (int)(std::log2(p)));
	}
	else
	{
		// 任意の n
		//n = M_128;
		n = mp::pow(mp::uint128_t(2), 117);
	}

	// DBG_cnt_div : 除算実行回数
	//							< 2^128
	mp::uint128_t DBG_cnt_div = (mp::uint128_t(0x0000000000000000) << 64) 
												  + mp::uint128_t(0x0000000000000fff);
	//mp::uint128_t DBG_cnt_div = M_128;

	bool DEBUG = 1;
	bool Cx_floor = 1;
	bool p_gt_2_to_the_power_of_63 = p > std::pow(2, 63) ? 1 : 0;
	
	//  -----------------------------------------------------------------------------------------------
	// q_n := [M_128 / p]
	mp::uint128_t q_n = n / p;
	// r_n := M_128 % p
	uint64_t  r_n = (uint64_t)(n % p);

	// pcs_endpoint : 端点の個数
	//							 := 2 // if r_n != 0 // M_128, (M_128 - r_n) の 2 点
	//							 := 1 // else // M_128 の 1 点
	unsigned short pcs_endpoint = r_n == 0 ? 1 : 2;

	// cnt_div_excluding_endpoint : 端点を除く除算実行回数
	//												  := DBG_cnt_div - pcs_endpoint
	mp::uint128_t cnt_div_excluding_endpoint = DBG_cnt_div - pcs_endpoint;
	
	// cnt_div_set : 実行する除算セット回数
	//                    := [(cnt_div_excluding_endpoint-1)/cnt_in_div_set] + 1
	mp::uint128_t cnt_div_set = ((cnt_div_excluding_endpoint - 1) / pcs_check_points_in_div_set) + 1;
	
	// DBG_cnt_div_max -----------------------------------------------------------------------------------------------
	// DBG_cnt_div_max : 除算実行回数の最大値
	//								   := cnt_in_div_set * q_n + pcs_endpoint
	mp::uint128_t DBG_cnt_div_max = pcs_check_points_in_div_set * q_n + pcs_endpoint;
	{
		// DBG_cnt_div の制約
		if (DBG_cnt_div > DBG_cnt_div_max)
		{
			DBG_cnt_div = DBG_cnt_div_max;
			std::cerr << "警告: " << "除算実行回数が最大値を超えています : DBG_cnt_div = DBG_cnt_div_max に制限されました" << std::endl;
		}
	}

	// expected -----------------------------------------------------------------------------------------------
	mp::uint128_t expected_quotient = q_n;
	uint64_t expected_remainder = r_n;

	// Cx -----------------------------------------------------------------------------------------------
	mp::uint128_t Cx_128;
	if (Cx_floor)
	{
		// Cx_128_floor := [two_to_the_power_of_128 / p]
		//							   < 2^127 (p > 2)
		Cx_128 = (mp::uint128_t)(two_to_the_power_of_128 / p);
	}
	else
	{
		// Cx_128_ceiling := [two_to_the_power_of_128 / p] + 1
		//								  < (2^127) + 1 (p > 2)
		Cx_128 = (mp::uint128_t)(two_to_the_power_of_128 / p) + 1;
	}
	
	// k -----------------------------------------------------------------------------------------------
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

	// k : [2, p-2] を除算実行回数に従って等間隔に進む
	//    = 2 + (p-1)-2 % cnt_div_set // if cnt_div_set <= (p-1)-2
	//	   = 2 // else
	uint64_t k = 2 + r_k;

	// increment_k : increment_k のデクリメント値
	// 												     := [((p-1)-2) / cnt_div_set] // if cnt_div_set <= (p-1)-2
	//													     := 1 // else
	uint64_t increment_k = p_k;

	// マクロ生成 -----------------------------------------------------------------------------------------------
	std::cout << "DBG_cnt_div_max_hi: " << boost::format("0x%016x") % (DBG_cnt_div_max >> 64) << std::endl;
	std::cout << "DBG_cnt_div_max_lo: " << boost::format("0x%016x") % (DBG_cnt_div_max & 0xffffffffffffffff) << std::endl;
	std::cout << std::endl;

	// マクロ生成 -----------------------------------------------------------------------------------------------
	if (DEBUG)
	{
		std::cout << "%define" << " " << "DEBUG" << std::endl;
	}
	if (q_le_64bit)
	{
		std::cout << "%define" << " " << "q_le_64bit" << std::endl;
		if (div_optimized)
		{
			std::cout << "%define" << " " << "div_optimized" << std::endl;
		}
	}
	if (Cx_floor)
	{
		std::cout << "%define" << " " << "Cx_128_floor" << std::endl;
	}
	if (p_gt_2_to_the_power_of_63)
	{
		std::cout << "%define" << " " << "p_gt_2_to_the_power_of_63" << std::endl;
	}

	std::cout << "%define" << " " << "m_p" << " " << boost::format("0x%016x") % p << std::endl;
	std::cout << "%define" << " " << "m_Cx_128_hi" << " " << boost::format("0x%016x") % (Cx_128 >> 64) << std::endl;
	std::cout << "%define" << " " << "m_Cx_128_lo" << " " << boost::format("0x%016x") % (Cx_128 & 0xffffffffffffffff) << std::endl;
	
	std::cout << "%define" << " " << "m_pcs_check_points_in_div_set" << " " << pcs_check_points_in_div_set << std::endl;
	
	std::cout << "%define" << " " << "m_DBG_cnt_div_hi" << " " << boost::format("0x%016x") % (DBG_cnt_div >> 64) << std::endl;
	std::cout << "%define" << " " << "m_DBG_cnt_div_lo" << " " << boost::format("0x%016x") % (DBG_cnt_div & 0xffffffffffffffff) << std::endl;
	
	std::cout << "%define" << " " << "m_n_init_hi" << " " << boost::format("0x%016x") % (n >> 64) << std::endl;
	std::cout << "%define" << " " << "m_n_init_lo" << " " << boost::format("0x%016x") % (n & 0xffffffffffffffff) << std::endl;
	std::cout << "%define" << " " << "m_init_expected_quotient_hi" << " " << boost::format("0x%016x") % (expected_quotient >> 64) << std::endl;
	std::cout << "%define" << " " << "m_init_expected_quotient_lo" << " " << boost::format("0x%016x") % (expected_quotient & 0xffffffffffffffff) << std::endl;
	std::cout << "%define" << " " << "m_init_expected_remainder" << " " << boost::format("0x%016x") % expected_remainder << std::endl;
	std::cout << "%define" << " " << "m_init_k" << " " << boost::format("0x%016x") % k << std::endl;
	std::cout << "%define" << " " << "m_increment_k" << " " << boost::format("0x%016x") % increment_k << std::endl;

	std::cout << "%define m_init_diff_p_minus_1_to_k m_p-1 - m_init_k" << std::endl;
	return 0;
}

	// -----------------------------------------------------------------------------------------------
	//struct NASM_macro_info
	//{
	//	char const* const directive; // %define, %assign など
	//	char const* const identifier; // マクロ名
	//	char const* const token_string; // 置換文字列
	//};

	//std::vector<NASM_macro_info> vec_NASM_macro;

	//std::ofstream ofs_asm("plain_macro.asm");
	//if (ofs_asm.bad())
	//{
	//	std::cerr << "!! ofs_asm: 出力ファイルのオープンに失敗しました" << std::endl;
	//	std::exit(1);
	//}

	//ofs_asm.close();
