package kasir.kasir;

import org.junit.jupiter.api.Test;
import org.junit.platform.suite.api.SelectPackages;
import org.junit.platform.suite.api.Suite;

@Suite
@SelectPackages("kasir.kasir.service") // Mantra pemanggil pasukan test
class KasirApplicationTests {

	@Test
	void contextLoads() {
	}

}
